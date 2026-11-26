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
    try
    {
        heidiText := A_Clipboard

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
    finally
    {
        ; Toujours redonner la main, meme en cas d'erreur
        BlockInput(false)
    }

    A_Clipboard := heidiText

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

    PasteToField(p.corps)
    BlockInput(false)
    A_Clipboard := heidiText
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
    finally
        BlockInput(false)
    DOCS_COLLES[i] := true
    A_Clipboard := heidiText
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
        texte := StrReplace(b, "**", "")
        titre := Trim(StrSplit(texte, "`n", "`r")[1])
        typeImg := RegExMatch(titre, "[—–-]\s*(.+)$", &mt) ? mt[1] : titre
        docs.Push({libelle: "Imagerie — " typeImg, texte: texte})
    }
    return docs
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
PasteToField(textValue)
{
    if (textValue = "")
    {
        Sleep(50)
        return
    }

    A_Clipboard := textValue
    Sleep(150)
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

    try
    {
        Loop Files, LBX_TEMP_DIR "\Etiquette_*.lbx"
        {
            dateModif := FileGetTime(A_LoopFileFullPath,"M")
            if (DateDiff(A_Now, dateModif, "Days") > 30)
                FileDelete(A_LoopFileFullPath)
        }
    }

    Run('"' PTEDIT_EXE '" "' fichierTemp '"')
}

;---------------------------------------------------------------
; CTRL+ALT+V : vide DEFINITIVEMENT le dossier patient (sans Corbeille).
; A utiliser APRES l'import dans Heidi. Le dossier lui-meme est conserve.
;---------------------------------------------------------------
ViderDossierPatient()
{
    if !DirExist(DOSSIER_PATIENT)
    {
        NotifierDossierPatient("Dossier patient introuvable : rien n'a ete supprime.")
        return
    }

    elements := []
    Loop Files, DOSSIER_PATIENT "\*", "FD"
        elements.Push({chemin: A_LoopFilePath, estDossier: InStr(A_LoopFileAttrib, "D") > 0})

    nb := 0
    Loop Files, DOSSIER_PATIENT "\*", "FR"
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
