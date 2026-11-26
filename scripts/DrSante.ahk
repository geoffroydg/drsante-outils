#Requires AutoHotkey v2.0
#SingleInstance Force

;===========================================================
; IMPORT HEIDI -> DR SANTE  (script unique, base : final v7)
;
; RACCOURCIS PAR DEFAUT (modifiables sur chaque poste depuis la fenetre
; "Dr Sante outils" > "Modifier les raccourcis" ; enregistres dans
; config.ini, section [raccourcis], jamais ecrases par les mises a jour) :
;
; CTRL  + CLIC MOLETTE      = Consultation ADULTE
; ALT   + CLIC MOLETTE      = Consultation ENFANT (+ etiquette si activee)
; MAJ   + CLIC MOLETTE      = Courrier d'adressage (1 courrier par appui)
; WIN   + CLIC MOLETTE      = Menu des autres documents : kine, soins
;                             infirmiers, certificat, imagerie (clic = collage ;
;                             colle directement s'il n'y en a qu'un)
; CTRL+ALT+V                = Vide definitivement le dossier patient
;
; Plusieurs courriers dans la meme consultation : chacun va dans un document
; Dr Sante SEPARE (a creer entre deux appuis). Tant que le presse-papiers ne
; change pas, chaque appui colle le suivant. Dans le menu des documents, ceux
; deja colles sont coches.
;
; REGLAGES PROPRES A CHAQUE ORDINATEUR : fichier config.ini
;   %APPDATA%\DrSanteOutils\config.ini  (cree par l'installateur,
;   jamais ecrase par les mises a jour).
;===========================================================

CONFIG_FILE := EnvGet("APPDATA") "\DrSanteOutils\config.ini"

global DOSSIER_PATIENT  := IniRead(CONFIG_FILE, "general",  "dossier_patient", EnvGet("USERPROFILE") "\Documents\Dossier patient")
global ETIQUETTE_ACTIVE := (IniRead(CONFIG_FILE, "general",  "etiquette", "0") = "1")
global LBX_TEMPLATE     := IniRead(CONFIG_FILE, "etiquette", "lbx", "")
global PTEDIT_EXE       := IniRead(CONFIG_FILE, "etiquette", "ptedit", "C:\Program Files (x86)\Brother\Ptedit54\ptedit54.exe")
global LBX_TEMP_DIR     := A_Temp "\EtiquettesDrSante"
global MARQUEUR_PATIENT := ".dossier_patient_drsante"   ; cree par l'installation

; Etat des "curseurs" (courrier / kine / infirmier courant). Geres par le script.
global COURRIER_STATE_TEXT := ""
global COURRIER_STATE_INDEX := 0
; Menu des documents : documents deja colles pour le presse-papiers courant
global DOCS_STATE_TEXT := ""
global DOCS_COLLES := Map()

; Ligne fixe inseree par le script (jamais par Heidi) apres la formule de politesse
global COURRIER_MACRO_PREFIX := "Je vous adresse {CivilitePatient} {NomPatient} {PrenomPatient}, né(e) le {DateNaissancePatient}, agé(e) de {AgePatient} "
; Macros Dr Sante inserees quand Heidi n'a rien redige pour antecedents / traitements
global COURRIER_MACRO_ANTECEDENTS := "{ListePathologiesAntecedents}"
global COURRIER_MACRO_TRAITEMENTS := "{ListeCompleteTraitements}"
; Identite du patient dans les certificats. Heidi ecrit directement les macros
; Dr Sante ; @IDENTITE@ (ancien prompt) est encore remplace par securite.
global CERTIFICAT_MACRO_IDENTITE := "{NomPrenomPatient}, né(e) le {DateNaissancePatient},"

;---------------------------------------------------------------
; RACCOURCIS : lus dans config.ini [raccourcis] (syntaxe AutoHotkey v2 :
; ^ = Ctrl, ! = Alt, + = Maj, # = Win ; ex. ^!MButton). Les imports
; ne marchent que dans Dr Sante ; "vider" marche partout.
; Valeur invalide ou en double -> message + valeur par defaut.
;---------------------------------------------------------------
global RACCOURCIS := [
    {cle: "adulte",    defaut: "^MButton",  drsante: true,  nom: "Consultation adulte",            action: (*) => ImportDrSante("adulte")},
    {cle: "enfant",    defaut: "!MButton",  drsante: true,  nom: "Consultation enfant",            action: (*) => ImportDrSante("enfant")},
    {cle: "courrier",  defaut: "+MButton",  drsante: true,  nom: "Courrier d'adressage",           action: (*) => ImportCourrierDrSante()},
    {cle: "documents", defaut: "#MButton", drsante: true, nom: "Menu des documents",            action: (*) => MenuDocumentsDrSante()},
    {cle: "vider",     defaut: "^!v",       drsante: false, nom: "Vider le dossier patient",       action: (*) => ViderDossierPatient()}
]
ActiverRaccourcis()
PurgerEtiquettesTemporaires()

ActiverRaccourcis()
{
    utilises := Map()
    utilises.CaseSense := false
    erreurs := ""
    for r in RACCOURCIS
    {
        touche := Trim(IniRead(CONFIG_FILE, "raccourcis", r.cle, r.defaut))
        if (touche = "")
            touche := r.defaut
        if utilises.Has(touche)
        {
            erreurs .= "- " r.nom " : " touche " deja utilise par '" utilises[touche] "'`n"
            touche := r.defaut
        }
        if !DefinirRaccourci(touche, r)
        {
            erreurs .= "- " r.nom " : '" touche "' invalide`n"
            touche := r.defaut
            DefinirRaccourci(touche, r)
        }
        utilises[touche] := r.nom
    }
    if (erreurs != "")
        MsgBox("Certains raccourcis de config.ini ne sont pas utilisables :`n`n" erreurs
            . "`nLes valeurs par defaut sont utilisees a la place.`n"
            . "Corrigez-les dans la fenetre 'Dr Sante outils' > 'Modifier les raccourcis'.",
            "Raccourcis Dr Sante", "Icon!")
}

DefinirRaccourci(touche, r)
{
    try
    {
        if r.drsante
            HotIfWinActive("ahk_exe DrSanteDesktop.exe")
        else
            HotIfWinActive()
        Hotkey(touche, r.action, "On")
        HotIfWinActive()
        return true
    }
    catch
    {
        HotIfWinActive()
        return false
    }
}

;---------------------------------------------------------------
; Preparation commune : gel clavier/souris physiques pendant le collage,
; envoi touche par touche (30 ms / 20 ms), relachement des modificateurs
; encore enfonces (quel que soit le raccourci choisi).
; PIEGE : relacher Alt ou Win "tout seul" active le menu de l'application
; ou le menu Demarrer -> on presse Ctrl AVANT de relacher Alt / Win.
;---------------------------------------------------------------
PrepareSend()
{
    BlockInput(true)
    SendMode("Event")
    SetKeyDelay(30, 20)
    seq := "{Blind}{LCtrl down}"
    for k in ["LWin", "RWin", "LAlt", "RAlt", "LShift", "RShift", "RCtrl"]
        if GetKeyState(k)
            seq .= "{" k " up}"
    seq .= "{LCtrl up}"
    Send(seq)
    Sleep(150)
}

;===================================================================
; IMPORT CONSULTATION (adulte / enfant)
;===================================================================
ImportDrSante(mode)
{
    PrepareSend()
    heidiText := A_Clipboard
    try
    {

        if !InStr(heidiText,"[ANAMNESE]") or !InStr(heidiText,"[FIN_DRSANTE]")
        {
            BlockInput(false) ; indispensable avant une MsgBox
            MsgBox("Le presse-papiers ne contient pas une synthese Heidi valide"
                . " (bloc [ANAMNESE]...[FIN_DRSANTE] introuvable).`n`n"
                . "Import annule : rien n'a ete colle dans Dr Sante.`n`n"
                . "Verifiez que vous avez bien copie la synthese complete depuis Heidi"
                . " avant d'utiliser le raccourci.",
                "Import annule", "Icon!")
            return
        }

        RegExMatch(heidiText,"is)\[ANAMNESE\]\s*\r?\n(.*?)(?=\s*\[EXAMEN\])",&anamneseMatch)
        RegExMatch(heidiText,"is)\[EXAMEN\]\s*\r?\n(.*?)(?=\s*\[DIAGNOSTIC\])",&examenMatch)
        RegExMatch(heidiText,"is)\[DIAGNOSTIC\]\s*\r?\n(.*?)(?=\s*\[SYNTHESE\])",&diagnosticMatch)
        RegExMatch(heidiText,"is)\[SYNTHESE\]\s*\r?\n(.*?)(?=\s*\[TAILLE\])",&syntheseMatch)

        RegExMatch(heidiText,"is)\[TAILLE\]\s*\r?\n(.*?)(?=\s*\[POIDS\])",&tailleMatch)
        RegExMatch(heidiText,"is)\[POIDS\]\s*\r?\n(.*?)(?=\s*\[SATURATION\])",&poidsMatch)
        RegExMatch(heidiText,"is)\[SATURATION\]\s*\r?\n(.*?)(?=\s*\[PAS\])",&saturationMatch)
        RegExMatch(heidiText,"is)\[PAS\]\s*\r?\n(.*?)(?=\s*\[PAD\])",&pasMatch)
        RegExMatch(heidiText,"is)\[PAD\]\s*\r?\n(.*?)(?=\s*\[FC\])",&padMatch)
        RegExMatch(heidiText,"is)\[FC\]\s*\r?\n(.*?)(?=\s*\[TEMPERATURE\])",&fcMatch)
        RegExMatch(heidiText,"is)\[TEMPERATURE\]\s*\r?\n(.*?)(?=\s*\[PERIMETRE_CRANIEN\])",&temperatureMatch)
        RegExMatch(heidiText,"is)\[PERIMETRE_CRANIEN\]\s*\r?\n(.*?)(?=\s*\[FIN_DRSANTE\])",&pcMatch)

        anamnese := anamneseMatch ? Trim(anamneseMatch[1]," `t`r`n") : ""
        examen := examenMatch ? Trim(examenMatch[1]," `t`r`n") : ""
        diagnostic := diagnosticMatch ? Trim(diagnosticMatch[1]," `t`r`n") : ""
        synthese := syntheseMatch ? Trim(syntheseMatch[1]," `t`r`n") : ""

        taille := tailleMatch ? Trim(tailleMatch[1]," `t`r`n") : ""
        poids := poidsMatch ? Trim(poidsMatch[1]," `t`r`n") : ""
        saturation := saturationMatch ? Trim(saturationMatch[1]," `t`r`n") : ""
        pas := pasMatch ? Trim(pasMatch[1]," `t`r`n") : ""
        pad := padMatch ? Trim(padMatch[1]," `t`r`n") : ""
        fc := fcMatch ? Trim(fcMatch[1]," `t`r`n") : ""
        temperature := temperatureMatch ? Trim(temperatureMatch[1]," `t`r`n") : ""
        pc := pcMatch ? Trim(pcMatch[1]," `t`r`n") : ""

        PasteToField(anamnese)
        Send("{Tab}")
        Sleep(100)

        PasteToField(examen)
        Send("{Tab}")
        Sleep(100)

        PasteToField(diagnostic)
        Send("{Tab}")
        Sleep(100)

        PasteToField(synthese)
        Sleep(100)

        Loop 29
        {
            Send("{Tab}")
            Sleep(35)
        }

        Sleep(200)

        if (mode = "adulte")
        {
            PasteToField(taille)
            Send("{Tab}")
            Sleep(100)

            PasteToField(poids)
            Send("{Tab}")
            Sleep(100)

            PasteToField(saturation)
            Send("{Tab}")
            Sleep(100)

            PasteToField(pas)
            Send("{Tab}")
            Sleep(100)

            PasteToField(pad)
            Send("{Tab}")
            Sleep(100)

            PasteToField(fc)
            Send("{Tab}")
            Sleep(100)

            PasteToField(temperature)
        }
        else
        {
            PasteToField(taille)
            Send("{Tab}")
            Sleep(100)

            PasteToField(poids)
            Send("{Tab}")
            Sleep(100)

            PasteToField(saturation)
            Send("{Tab}")
            Sleep(100)

            PasteToField(fc)
            Send("{Tab}")
            Sleep(100)

            PasteToField(temperature)
            Send("{Tab}")
            Sleep(100)

            PasteToField(pc)
        }
    }
    catch as err
    {
        BlockInput(false)
        CopierPressePapiersPrive(heidiText)
        MessageCollageInterrompu(err)
        return
    }
    finally
    {
        ; Toujours redonner la main, meme en cas d'erreur
        BlockInput(false)
    }

    CopierPressePapiersPrive(heidiText)

    if (mode = "enfant" && ETIQUETTE_ACTIVE)
    {
        etiquette := ExtractEtiquette(heidiText)
        if (etiquette != "")
        {
            try
            {
                CreateAndOpenLabel(etiquette)
            }
            catch as err
            {
                MsgBox("Etiquette non generee automatiquement.`n`nErreur : " err.Message
                    . "`n`nVerifiez dans config.ini : chemin du modele LBX, chemin de ptedit54.exe,"
                    . " et que le SDK b-PAC est installe (fourni avec P-touch Editor).",
                    "Erreur etiquette", "Icon!")
            }
        }
    }
}

;===================================================================
; IMPORT COURRIER D'ADRESSAGE  (Maj + clic molette)
; La ligne d'identite patient (macros Dr Sante) est inseree par CE script.
;===================================================================
ImportCourrierDrSante()
{
    global COURRIER_STATE_TEXT, COURRIER_STATE_INDEX

    PrepareSend()
    heidiText := A_Clipboard

    if !InStr(heidiText,"[COURRIER]") or !InStr(heidiText,"[FIN_COURRIER]")
    {
        BlockInput(false)
        MsgBox("Le presse-papiers ne contient pas de courrier balise"
            . " (balises [COURRIER]...[FIN_COURRIER] introuvables).`n`n"
            . "Import annule : rien n'a ete colle dans Dr Sante.`n`n"
            . "Verifiez que le prompt Heidi genere bien ces balises autour"
            . " du courrier, et qu'un courrier a effectivement ete declenche"
            . " dans cette consultation.",
            "Import annule", "Icon!")
        return
    }

    courriersBruts := ExtractAllCourriers(heidiText)
    nbCourriers := courriersBruts.Length

    if (nbCourriers = 0)
    {
        BlockInput(false)
        MsgBox("Balises [COURRIER] trouvees mais contenu vide. Rien n'a ete colle.",
            "Import annule", "Icon!")
        return
    }

    wrapped := false
    if (heidiText = COURRIER_STATE_TEXT)
    {
        COURRIER_STATE_INDEX += 1
        if (COURRIER_STATE_INDEX > nbCourriers)
        {
            COURRIER_STATE_INDEX := 1
            wrapped := true
        }
    }
    else
    {
        COURRIER_STATE_TEXT := heidiText
        COURRIER_STATE_INDEX := 1
    }

    p := BuildCourrierParts(courriersBruts[COURRIER_STATE_INDEX])

    if (nbCourriers > 1)
    {
        msg := wrapped
            ? ("Retour au courrier 1/" nbCourriers " - tous avaient deja ete"
                . " colles, on recommence.")
            : ("Courrier " COURRIER_STATE_INDEX "/" nbCourriers " ("
                . p.specialite ") colle dans ce document.")
        ShowCourrierTooltip(msg)
    }

    try
        PasteToField(p.corps)
    catch as err
    {
        BlockInput(false)
        CopierPressePapiersPrive(heidiText)
        MessageCollageInterrompu(err)
        return
    }
    finally
        BlockInput(false)
    CopierPressePapiersPrive(heidiText)
}

;===================================================================
; MENU DES DOCUMENTS  (Win + clic molette)
; Kine, soins infirmiers, certificats, imagerie : un menu sous la souris
; liste les documents trouves dans le presse-papiers ; un clic colle le
; document choisi. Un seul document => collage direct, sans menu.
;===================================================================
MenuDocumentsDrSante()
{
    global DOCS_STATE_TEXT, DOCS_COLLES

    heidiText := A_Clipboard
    docs := ListerDocuments(heidiText)

    if (docs.Length = 0)
    {
        MsgBox("Aucun document trouve dans le presse-papiers"
            . " (kine, soins infirmiers, certificat, imagerie).`n`n"
            . "Rien n'a ete colle dans Dr Sante.`n`n"
            . "Verifiez que vous avez copie la synthese complete depuis Heidi,"
            . " que Heidi a bien genere ces documents, et que le prompt Heidi est a jour."
            . "`n(Le courrier se colle avec son propre raccourci.)",
            "Import annule", "Icon!")
        return
    }

    if (heidiText != DOCS_STATE_TEXT)
    {
        DOCS_STATE_TEXT := heidiText
        DOCS_COLLES := Map()
    }

    if (docs.Length = 1)
    {
        CollerDocument(docs[1], 1, heidiText)
        return
    }

    ; Relache les modificateurs du raccourci avant d'afficher le menu
    ; (sans bloquer clavier/souris : il faut pouvoir cliquer dans le menu)
    PrepareSend()
    BlockInput(false)

    fenetre := WinExist("A")
    m := Menu()
    for i, d in docs
    {
        libelle := (i <= 9 ? "&" i "  " : "") StrReplace(d.libelle, "&", "&&")
        m.Add(libelle, CollerDepuisMenu.Bind(docs, i, heidiText, fenetre))
        if DOCS_COLLES.Has(i)
            m.Check(libelle)
    }
    m.Show()
}

CollerDepuisMenu(docs, i, heidiText, fenetre, *)
{
    ; Le menu ferme, on s'assure de revenir dans la fenetre Dr Sante
    try
    {
        WinActivate(fenetre)
        WinWaitActive(fenetre, , 1)
    }
    CollerDocument(docs[i], i, heidiText)
}

CollerDocument(doc, i, heidiText)
{
    global DOCS_COLLES
    PrepareSend()
    try
        PasteToField(doc.texte)
    catch as err
    {
        BlockInput(false)
        CopierPressePapiersPrive(heidiText)
        MessageCollageInterrompu(err)
        return
    }
    finally
        BlockInput(false)
    DOCS_COLLES[i] := true
    CopierPressePapiersPrive(heidiText)
}

; Liste {libelle, texte} de tous les documents du presse-papiers, dans
; l'ordre : kine, soins infirmiers, certificats, imagerie.
ListerDocuments(heidiText)
{
    docs := []

    blocs := ExtractBlocks(heidiText, "KINE")
    for i, b in blocs
        docs.Push({libelle: "Kiné" (blocs.Length > 1 ? " " i "/" blocs.Length : "")
            . " — " ResumeLigne(b), texte: StrReplace(b, "**", "")})

    blocs := ExtractBlocks(heidiText, "INFIRMIER")
    for i, b in blocs
        docs.Push({libelle: "Soins infirmiers" (blocs.Length > 1 ? " " i "/" blocs.Length : "")
            . " — " ResumeLigne(b), texte: StrReplace(b, "**", "")})

    for b in ExtractBlocks(heidiText, "CERTIFICAT")
    {
        p := BuildCertificatParts(b)
        docs.Push({libelle: "Certificat — " (p.type != "" ? p.type : "certificat"), texte: p.corps})
    }

    for b in ExtractBlocks(heidiText, "IMAGERIE")
    {
        p := BuildImagerieParts(b)
        docs.Push({libelle: "Imagerie — " (p.type != "" ? p.type : ResumeLigne(p.corps)), texte: p.corps})
    }
    return docs
}

; Retire la ligne repere du type (IRM, SCANNER... ; ancien prompt :
; "ORDONNANCE D'IMAGERIE — TYPE") et le gras Markdown.
BuildImagerieParts(brut)
{
    lignes := StrSplit(StrReplace(brut, "**", ""), "`n", "`r")
    typeImg := ""
    debut := 1
    if (lignes.Length >= 1)
    {
        t := Trim(lignes[1])
        if RegExMatch(t, "i)^(ORDONNANCE D'IMAGERIE\s*[—–-]\s*)?(IRM|SCANNER|DOPPLER|ECHOGRAPHIE|ÉCHOGRAPHIE|MAMMOGRAPHIE|RADIOGRAPHIE)\s*$", &mt)
        {
            typeImg := mt[2]
            debut := 2
        }
    }
    corps := ""
    Loop lignes.Length - debut + 1
        corps .= (A_Index = 1 ? "" : "`r`n") . lignes[debut + A_Index - 1]
    return {type: typeImg, corps: Trim(corps, " `t`r`n")}
}

; Premiere ligne non vide d'un bloc, raccourcie (sert de repere dans le menu)
ResumeLigne(bloc)
{
    for l in StrSplit(StrReplace(bloc, "**", ""), "`n", "`r")
    {
        t := Trim(l)
        if (t != "")
            return StrLen(t) > 60 ? SubStr(t, 1, 57) "..." : t
    }
    return ""
}

; Retire la ligne repere (si presente) et le gras Markdown ; la ligne
; @IDENTITE@ est fondue dans la phrase (sans retour a la ligne).
BuildCertificatParts(brut)
{
    lignes := StrSplit(StrReplace(brut, "**", ""), "`n", "`r")
    typeCert := ""
    corps := ""
    joindre := false
    for i, l in lignes
    {
        t := Trim(l)
        if (i = 1 && RegExMatch(t, "i)^(SPORT|EPS|ENFANT MALADE)\s*[—–-]"))
        {
            typeCert := t
            continue
        }
        if (t = "@IDENTITE@")
        {
            corps := RTrim(corps, " `t") " " CERTIFICAT_MACRO_IDENTITE
            joindre := true
            continue
        }
        l := StrReplace(l, "@IDENTITE@", CERTIFICAT_MACRO_IDENTITE)
        if (joindre)
            corps .= " " LTrim(l, " `t")
        else
            corps .= (corps = "" ? "" : "`r`n") . l
        joindre := false
    }
    return {type: typeCert, corps: Trim(corps, " `t`r`n")}
}

;---------------------------------------------------------------
; Extrait tous les blocs [TAG]...[FIN_TAG]
;---------------------------------------------------------------
ExtractBlocks(heidiText, tag)
{
    blocs := []
    pos := 1
    motif := "is)\[" tag "\]\s*\r?\n(.*?)(?=\r?\n\s*\[FIN_" tag "\])"

    while (foundPos := RegExMatch(heidiText, motif, &m, pos))
    {
        contenu := Trim(m[1], " `t`r`n")
        if (contenu != "")
            blocs.Push(contenu)
        pos := foundPos + StrLen(m[0])
    }
    return blocs
}

ExtractAllCourriers(heidiText)
{
    return ExtractBlocks(heidiText, "COURRIER")
}

;---------------------------------------------------------------
; Info-bulle discrete (disparait seule)
;---------------------------------------------------------------
ShowCourrierTooltip(msg)
{
    ToolTip(msg)
    SetTimer(() => ToolTip(), -3000)
}

;---------------------------------------------------------------
; Decoupe un courrier en {specialite, corps} : la 1ere ligne (ex
; "CARDIOLOGIE") ne sert qu'au repere ; le corps recoit la macro
; d'identite patient juste apres "Chere Consoeur, Cher Confrere,".
; Tout ce que Heidi aurait ecrit avant "qui presente" est ignore.
;---------------------------------------------------------------
BuildCourrierParts(brut)
{
    lignes := StrSplit(brut, "`n", "`r")
    specialite := lignes.Length >= 1 ? Trim(lignes[1]) : ""

    resteLignes := []
    Loop lignes.Length
    {
        if (A_Index = 1)
            continue
        resteLignes.Push(lignes[A_Index])
    }

    reste := ""
    for i, l in resteLignes
    {
        reste .= l
        if (i < resteLignes.Length)
            reste .= "`r`n"
    }
    reste := Trim(reste, " `t`r`n")

    posApresGreeting := 1
    if RegExMatch(reste,"i)Chère Consœur,\s*Cher Confrère,\s*\r?\n\s*\r?\n",&mGreeting)
        posApresGreeting := InStr(reste, mGreeting[0]) + StrLen(mGreeting[0])

    avant := SubStr(reste, 1, posApresGreeting - 1)
    resteApresGreeting := SubStr(reste, posApresGreeting)

    if RegExMatch(resteApresGreeting,"i)qui présente",&mQuiPresente)
    {
        posQuiPresente := InStr(resteApresGreeting, mQuiPresente[0])
        apres := SubStr(resteApresGreeting, posQuiPresente)
    }
    else
    {
        ; Filet de securite : on garde tout plutot que de perdre du contenu
        apres := resteApresGreeting
    }

    corps := avant . COURRIER_MACRO_PREFIX . apres
    corps := InsertDrSanteAntecedentsTraitements(corps)

    return {specialite: specialite, corps: corps}
}

;---------------------------------------------------------------
; Si Heidi a laisse "Ses antecedents sont marques par:" (ou "Ses
; traitements habituels sont:") vide, on insere la macro Dr Sante
; correspondante : l'info est supposee presente dans le dossier.
;---------------------------------------------------------------
InsertDrSanteAntecedentsTraitements(corps)
{
    if RegExMatch(corps,"i)(Ses antécédents sont marqués par:[ \t]*)\r?\n[ \t]*\r?\n",&mAtcd)
    {
        remplacement := mAtcd[1] "`r`n" COURRIER_MACRO_ANTECEDENTS "`r`n`r`n"
        corps := StrReplace(corps, mAtcd[0], remplacement)
    }

    if RegExMatch(corps,"i)(Ses traitements habituels sont:[ \t]*)\r?\n[ \t]*\r?\n",&mTrt)
    {
        remplacement := mTrt[1] "`r`n" COURRIER_MACRO_TRAITEMENTS "`r`n`r`n"
        corps := StrReplace(corps, mTrt[0], remplacement)
    }

    return corps
}

;---------------------------------------------------------------
; Collage generique
;---------------------------------------------------------------
;---------------------------------------------------------------
; SECURITE : le collage s'arrete si Dr Sante n'est plus au premier plan
;---------------------------------------------------------------
VerifierFenetreDrSante()
{
    if !WinActive("ahk_exe DrSanteDesktop.exe")
        throw Error("FENETRE_DRSANTE")
}

MessageCollageInterrompu(err)
{
    if (err.Message = "FENETRE_DRSANTE")
        MsgBox("Collage interrompu : la fenetre Dr Sante n'etait plus au premier plan"
            . " (une autre fenetre s'est ouverte ou a ete cliquee).`n`n"
            . "Par securite, rien d'autre n'a ete colle. Verifiez le document,"
            . " puis relancez le raccourci.", "Collage interrompu", "Icon!")
    else
        MsgBox("Collage interrompu par une erreur :`n`n" err.Message, "Collage interrompu", "Icon!")
}

;---------------------------------------------------------------
; SECURITE : presse-papiers exclu de l'historique Windows (Win+V) et de la
; synchronisation cloud Microsoft. En cas d'echec : copie classique.
;---------------------------------------------------------------
CopierPressePapiersPrive(texte)
{
    static fmtHisto := DllCall("RegisterClipboardFormat", "Str", "CanIncludeInClipboardHistory", "UInt")
    static fmtCloud := DllCall("RegisterClipboardFormat", "Str", "CanUploadToCloudClipboard", "UInt")
    ok := false
    try
    {
        ouvert := false
        Loop 10
        {
            if DllCall("OpenClipboard", "Ptr", A_ScriptHwnd)
            {
                ouvert := true
                break
            }
            Sleep(20)
        }
        if ouvert
        {
            try
            {
                DllCall("EmptyClipboard")
                hTexte := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", (StrLen(texte) + 1) * 2, "Ptr")
                pTexte := DllCall("GlobalLock", "Ptr", hTexte, "Ptr")
                StrPut(texte, pTexte, "UTF-16")
                DllCall("GlobalUnlock", "Ptr", hTexte)
                ok := (DllCall("SetClipboardData", "UInt", 13, "Ptr", hTexte, "Ptr") != 0)
                for fmt in [fmtHisto, fmtCloud]
                {
                    h := DllCall("GlobalAlloc", "UInt", 0x2, "UPtr", 4, "Ptr")
                    pz := DllCall("GlobalLock", "Ptr", h, "Ptr")
                    NumPut("UInt", 0, pz)
                    DllCall("GlobalUnlock", "Ptr", h)
                    DllCall("SetClipboardData", "UInt", fmt, "Ptr", h, "Ptr")
                }
            }
            finally
                DllCall("CloseClipboard")
        }
    }
    catch
        ok := false
    if (!ok || A_Clipboard != texte)
        A_Clipboard := texte
}

PasteToField(textValue)
{
    if (textValue = "")
    {
        Sleep(50)
        return
    }

    ; Macros Dr Sante parfois ecrites {{Macro}} par Heidi : une seule paire
    textValue := RegExReplace(textValue, "\{\{(\w+)\}\}", "{$1}")
    CopierPressePapiersPrive(textValue)
    Sleep(150)
    ; SECURITE : ne jamais coller de donnees patient ailleurs que dans Dr Sante
    ; (fenetre surgissante, messagerie, navigateur...)
    VerifierFenetreDrSante()
    Send("^v")
    Sleep(100)
}

;---------------------------------------------------------------
; ETIQUETTE CARNET DE SANTE (uniquement si etiquette=1 dans config.ini)
;---------------------------------------------------------------
ExtractEtiquette(heidiText)
{
    if !RegExMatch(heidiText,"is)\[ETIQUETTE CARNET DE SANT.\]\s*\r?\n(.*?)(?=\r?\n\s*\*{0,2}\s*\[DRSANTE\])",&m)
        return ""

    txt := Trim(m[1]," `t`r`n")
    txt := StrReplace(txt,"**","")

    return Trim(txt," `t`r`n")
}

CreateAndOpenLabel(contenuTexte)
{
    doc := ""
    try
        doc := ComObject("bpac.Document")
    catch
    {
        try
            doc := ComObject("BrssCom.Document")
        catch as e2
            throw Error("Impossible de creer l'objet b-PAC (SDK non installe ou non enregistre). " e2.Message)
    }

    try
    {
        if !RegExMatch(LBX_TEMPLATE, "i)\.lbx$") || !FileExist(LBX_TEMPLATE)
            throw Error("Modele d'etiquette introuvable ou invalide : " LBX_TEMPLATE)
        if !doc.Open(LBX_TEMPLATE)
            throw Error("Impossible d'ouvrir le modele : " LBX_TEMPLATE)

        nbZonesTexte := ""
        try
            nbZonesTexte := doc.GetTextCount()

        ecrit := false
        for essaiIndex in [0, 1]
        {
            try
                ecrit := doc.SetText(essaiIndex, contenuTexte)
            catch
                ecrit := false
            if (ecrit)
                break
        }

        if !ecrit
            throw Error("L'ecriture du texte a echoue (SetText a renvoye Faux)."
                . " Zones de texte detectees : " nbZonesTexte ". Verifiez qu'il y a"
                . " bien exactement UNE zone de texte sur l'etiquette dans P-touch Editor.")

        if !DirExist(LBX_TEMP_DIR)
            DirCreate(LBX_TEMP_DIR)

        horodatage := FormatTime(A_Now,"yyyyMMdd_HHmmss")
        fichierTemp := LBX_TEMP_DIR "\Etiquette_" horodatage ".lbx"

        doc.SaveAs(1, fichierTemp)
    }
    finally
    {
        try
            doc.Close()
    }

    PurgerEtiquettesTemporaires()

    ; SECURITE : n'executer que P-touch Editor installe dans Program Files
    ; (config.ini est modifiable sans droits administrateur)
    if !PteditValide(PTEDIT_EXE)
        throw Error("Chemin de P-touch Editor refuse (doit etre ptedit*.exe dans Program Files) : " PTEDIT_EXE)
    Run('"' PTEDIT_EXE '" "' fichierTemp '"')
}

;---------------------------------------------------------------
; CTRL+ALT+V : vide DEFINITIVEMENT le dossier patient (sans Corbeille).
; A utiliser APRES l'import dans Heidi. Le dossier lui-meme est conserve.
;---------------------------------------------------------------
PteditValide(chemin)
{
    if !FileExist(chemin) || InStr(chemin, "..")
        return false
    SplitPath(chemin, &nom)
    if !RegExMatch(nom, "i)^ptedit\d*\.exe$")
        return false
    for base in [EnvGet("ProgramFiles"), EnvGet("ProgramFiles(x86)")]
        if (base != "" && InStr(chemin, base "\") = 1)
            return true
    return false
}

; Les etiquettes temporaires contiennent des donnees patient : supprimees
; apres 12 h (au lieu de 30 jours), et a chaque demarrage du script.
PurgerEtiquettesTemporaires()
{
    try
    {
        Loop Files, LBX_TEMP_DIR "\Etiquette_*.lbx"
        {
            dateModif := FileGetTime(A_LoopFileFullPath,"M")
            if (DateDiff(A_Now, dateModif, "Hours") >= 12)
                try FileDelete(A_LoopFileFullPath)
        }
    }
}

ViderDossierPatient()
{
    if !DirExist(DOSSIER_PATIENT)
    {
        NotifierDossierPatient("Dossier patient introuvable : rien n'a ete supprime.")
        return
    }
    ; SECURITE : on ne vide qu'un dossier reconnu comme dossier patient
    ; (fichier marqueur cree par l'installation), jamais une racine ni le profil.
    if (StrLen(RTrim(DOSSIER_PATIENT, "\")) <= 3 || RTrim(DOSSIER_PATIENT, "\") = EnvGet("USERPROFILE")
        || !FileExist(DOSSIER_PATIENT "\" MARQUEUR_PATIENT))
    {
        MsgBox("Ce dossier n'est pas reconnu comme dossier patient :`n" DOSSIER_PATIENT
            . "`n`nPar securite, rien n'a ete supprime. Ouvrez 'Dr Sante outils' puis"
            . " 'Modifier les reglages' pour choisir un dossier dedie.", "Dossier patient", "Icon!")
        return
    }

    ; Fin de consultation : le presse-papiers (synthese Heidi) est vide aussi,
    ; pour ne jamais coller les donnees d'un patient dans le dossier du suivant.
    try CopierPressePapiersPrive("")

    elements := []
    Loop Files, DOSSIER_PATIENT "\*", "FD"
        if (A_LoopFileName != MARQUEUR_PATIENT)
            elements.Push({chemin: A_LoopFilePath, estDossier: InStr(A_LoopFileAttrib, "D") > 0})

    nb := 0
    Loop Files, DOSSIER_PATIENT "\*", "FR"
        if (A_LoopFileName != MARQUEUR_PATIENT)
            nb++

    echecs := 0
    for e in elements
    {
        try
        {
            if e.estDossier
                DirDelete(e.chemin, true)
            else
                FileDelete(e.chemin)
        }
        catch
            echecs++
    }

    if (echecs > 0)
        NotifierDossierPatient("ATTENTION : " echecs " element(s) non supprime(s) (fichier ouvert ?). Fermez-le puis recommencez.")
    else
        NotifierDossierPatient("Dossier vide : " nb " fichier(s) supprime(s) definitivement.")
}

NotifierDossierPatient(message)
{
    TrayTip(message, "Dossier patient", 1)
    SetTimer(() => TrayTip(), -4000)
}
