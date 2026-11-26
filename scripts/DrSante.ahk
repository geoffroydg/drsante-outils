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
; WIN   + CLIC MOLETTE      = Ordonnance de kine (1 ordonnance par appui)
; CTRL+ALT + CLIC MOLETTE   = Ordonnance de soins infirmiers (1 par appui)
; ALT+MAJ  + CLIC MOLETTE   = Certificat medical (1 certificat par appui)
; CTRL+MAJ + CLIC MOLETTE   = Ordonnance d'imagerie (1 ordonnance par appui)
; CTRL+ALT+V                = Vide definitivement le dossier patient
;
; Plusieurs courriers / ordonnances / certificats dans la meme consultation : chacun va
; dans un document Dr Sante SEPARE (a creer entre deux appuis). Tant que le
; presse-papiers ne change pas, chaque appui colle le suivant.
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
global KINE_STATE_TEXT := ""
global KINE_STATE_INDEX := 0
global INF_STATE_TEXT := ""
global INF_STATE_INDEX := 0
global CERT_STATE_TEXT := ""
global CERT_STATE_INDEX := 0
global IMG_STATE_TEXT := ""
global IMG_STATE_INDEX := 0

; Ligne fixe inseree par le script (jamais par Heidi) apres la formule de politesse
global COURRIER_MACRO_PREFIX := "Je vous adresse {CivilitePatient} {NomPatient} {PrenomPatient}, né(e) le {DateNaissancePatient}, agé(e) de {AgePatient} "
; Macros Dr Sante inserees quand Heidi n'a rien redige pour antecedents / traitements
global COURRIER_MACRO_ANTECEDENTS := "{ListePathologiesAntecedents}"
global COURRIER_MACRO_TRAITEMENTS := "{ListeCompleteTraitements}"
; Identite du patient dans les certificats (remplace la ligne @IDENTITE@ ecrite par Heidi)
global CERTIFICAT_MACRO_IDENTITE := "{NomPatient} {PrenomPatient}, né(e) le {DateNaissancePatient},"

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
    {cle: "kine",      defaut: "#MButton",  drsante: true,  nom: "Ordonnance de kine",             action: (*) => ImportKineDrSante()},
    {cle: "infirmier", defaut: "^!MButton", drsante: true,  nom: "Ordonnance de soins infirmiers", action: (*) => ImportInfirmierDrSante()},
    {cle: "certificat", defaut: "!+MButton", drsante: true, nom: "Certificat medical",             action: (*) => ImportCertificatDrSante()},
    {cle: "imagerie",  defaut: "^+MButton", drsante: true,  nom: "Ordonnance d'imagerie",          action: (*) => ImportImagerieDrSante()},
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
; IMPORT ORDONNANCE(S) DE KINE  (Win + clic molette)
;===================================================================
ImportKineDrSante()
{
    global KINE_STATE_TEXT, KINE_STATE_INDEX

    PrepareSend()
    heidiText := A_Clipboard

    if !InStr(heidiText,"[KINE]") or !InStr(heidiText,"[FIN_KINE]")
    {
        BlockInput(false)
        MsgBox("Le presse-papiers ne contient pas d'ordonnance de kine balisee"
            . " (balises [KINE]...[FIN_KINE] introuvables).`n`n"
            . "Import annule : rien n'a ete colle dans Dr Sante.`n`n"
            . "Verifiez que le prompt Heidi a bien genere une ordonnance de kine"
            . " dans cette consultation.",
            "Import annule", "Icon!")
        return
    }

    kinesBruts := ExtractBlocks(heidiText, "KINE")
    nbKines := kinesBruts.Length

    if (nbKines = 0)
    {
        BlockInput(false)
        MsgBox("Balises [KINE] trouvees mais contenu vide ou illisible. Rien n'a ete colle.",
            "Import annule", "Icon!")
        return
    }

    wrapped := false
    if (heidiText = KINE_STATE_TEXT)
    {
        KINE_STATE_INDEX += 1
        if (KINE_STATE_INDEX > nbKines)
        {
            KINE_STATE_INDEX := 1
            wrapped := true
        }
    }
    else
    {
        KINE_STATE_TEXT := heidiText
        KINE_STATE_INDEX := 1
    }

    if (nbKines > 1)
    {
        msg := wrapped
            ? ("Retour a l'ordonnance de kine 1/" nbKines " - toutes avaient deja"
                . " ete collees, on recommence.")
            : ("Ordonnance de kine " KINE_STATE_INDEX "/" nbKines
                . " collee dans ce document.")
        ShowCourrierTooltip(msg)
    }

    PasteToField(kinesBruts[KINE_STATE_INDEX])
    BlockInput(false)
    A_Clipboard := heidiText
}

;===================================================================
; IMPORT ORDONNANCE(S) DE SOINS INFIRMIERS  (Ctrl + Alt + clic molette)
; Les blancs ________ eventuels sont a completer par le medecin.
;===================================================================
ImportInfirmierDrSante()
{
    global INF_STATE_TEXT, INF_STATE_INDEX

    PrepareSend()
    heidiText := A_Clipboard

    if !InStr(heidiText,"[INFIRMIER]") or !InStr(heidiText,"[FIN_INFIRMIER]")
    {
        BlockInput(false)
        MsgBox("Le presse-papiers ne contient pas d'ordonnance de soins infirmiers balisee"
            . " (balises [INFIRMIER]...[FIN_INFIRMIER] introuvables).`n`n"
            . "Import annule : rien n'a ete colle dans Dr Sante.`n`n"
            . "Verifiez que Heidi a bien genere une ordonnance de soins infirmiers"
            . " dans cette consultation.",
            "Import annule", "Icon!")
        return
    }

    infsBruts := ExtractBlocks(heidiText, "INFIRMIER")
    nbInfs := infsBruts.Length

    if (nbInfs = 0)
    {
        BlockInput(false)
        MsgBox("Balises [INFIRMIER] trouvees mais contenu vide ou illisible. Rien n'a ete colle.",
            "Import annule", "Icon!")
        return
    }

    wrapped := false
    if (heidiText = INF_STATE_TEXT)
    {
        INF_STATE_INDEX += 1
        if (INF_STATE_INDEX > nbInfs)
        {
            INF_STATE_INDEX := 1
            wrapped := true
        }
    }
    else
    {
        INF_STATE_TEXT := heidiText
        INF_STATE_INDEX := 1
    }

    if (nbInfs > 1)
    {
        msg := wrapped
            ? ("Retour a l'ordonnance infirmiere 1/" nbInfs " - toutes avaient deja"
                . " ete collees, on recommence.")
            : ("Ordonnance infirmiere " INF_STATE_INDEX "/" nbInfs
                . " collee dans ce document.")
        ShowCourrierTooltip(msg)
    }

    PasteToField(infsBruts[INF_STATE_INDEX])
    BlockInput(false)
    A_Clipboard := heidiText
}

;===================================================================
; IMPORT CERTIFICAT(S) MEDICAL(AUX)  (Alt + Maj + clic molette)
; 1re ligne du bloc = repere du type (non collee) ; @IDENTITE@ est
; remplace par les macros Dr Sante (nom, prenom, date de naissance).
;===================================================================
ImportCertificatDrSante()
{
    global CERT_STATE_TEXT, CERT_STATE_INDEX

    PrepareSend()
    heidiText := A_Clipboard

    if !InStr(heidiText,"[CERTIFICAT]") or !InStr(heidiText,"[FIN_CERTIFICAT]")
    {
        BlockInput(false)
        MsgBox("Le presse-papiers ne contient pas de certificat balise"
            . " (balises [CERTIFICAT]...[FIN_CERTIFICAT] introuvables).`n`n"
            . "Import annule : rien n'a ete colle dans Dr Sante.`n`n"
            . "Verifiez que Heidi a bien genere un certificat dans cette consultation"
            . " et que le prompt Heidi est a jour.",
            "Import annule", "Icon!")
        return
    }

    certsBruts := ExtractBlocks(heidiText, "CERTIFICAT")
    nbCerts := certsBruts.Length

    if (nbCerts = 0)
    {
        BlockInput(false)
        MsgBox("Balises [CERTIFICAT] trouvees mais contenu vide ou illisible. Rien n'a ete colle.",
            "Import annule", "Icon!")
        return
    }

    wrapped := false
    if (heidiText = CERT_STATE_TEXT)
    {
        CERT_STATE_INDEX += 1
        if (CERT_STATE_INDEX > nbCerts)
        {
            CERT_STATE_INDEX := 1
            wrapped := true
        }
    }
    else
    {
        CERT_STATE_TEXT := heidiText
        CERT_STATE_INDEX := 1
    }

    p := BuildCertificatParts(certsBruts[CERT_STATE_INDEX])

    if (nbCerts > 1)
    {
        msg := wrapped
            ? ("Retour au certificat 1/" nbCerts " - tous avaient deja ete"
                . " colles, on recommence.")
            : ("Certificat " CERT_STATE_INDEX "/" nbCerts " (" p.type
                . ") colle dans ce document.")
        ShowCourrierTooltip(msg)
    }

    PasteToField(p.corps)
    BlockInput(false)
    A_Clipboard := heidiText
}

; Retire la ligne repere (si presente) et le gras Markdown ; la ligne
; @IDENTITE@ est fondue dans la phrase (sans retour a la ligne).
BuildCertificatParts(brut)
{
    lignes := StrSplit(StrReplace(brut, "**", ""), "`n", "`r")
    type := ""
    corps := ""
    joindre := false
    for i, l in lignes
    {
        t := Trim(l)
        if (i = 1 && RegExMatch(t, "i)^(SPORT|EPS|ENFANT MALADE)\s*[—–-]"))
        {
            type := t
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
    return {type: type, corps: Trim(corps, " `t`r`n")}
}

;===================================================================
; IMPORT ORDONNANCE(S) D'IMAGERIE  (Ctrl + Maj + clic molette)
; Une ordonnance par modalite ; le gras Markdown eventuel est retire.
;===================================================================
ImportImagerieDrSante()
{
    global IMG_STATE_TEXT, IMG_STATE_INDEX

    PrepareSend()
    heidiText := A_Clipboard

    if !InStr(heidiText,"[IMAGERIE]") or !InStr(heidiText,"[FIN_IMAGERIE]")
    {
        BlockInput(false)
        MsgBox("Le presse-papiers ne contient pas d'ordonnance d'imagerie balisee"
            . " (balises [IMAGERIE]...[FIN_IMAGERIE] introuvables).`n`n"
            . "Import annule : rien n'a ete colle dans Dr Sante.`n`n"
            . "Verifiez que Heidi a bien genere une ordonnance d'imagerie dans cette"
            . " consultation et que le prompt Heidi est a jour.",
            "Import annule", "Icon!")
        return
    }

    imgsBruts := ExtractBlocks(heidiText, "IMAGERIE")
    nbImgs := imgsBruts.Length

    if (nbImgs = 0)
    {
        BlockInput(false)
        MsgBox("Balises [IMAGERIE] trouvees mais contenu vide ou illisible. Rien n'a ete colle.",
            "Import annule", "Icon!")
        return
    }

    wrapped := false
    if (heidiText = IMG_STATE_TEXT)
    {
        IMG_STATE_INDEX += 1
        if (IMG_STATE_INDEX > nbImgs)
        {
            IMG_STATE_INDEX := 1
            wrapped := true
        }
    }
    else
    {
        IMG_STATE_TEXT := heidiText
        IMG_STATE_INDEX := 1
    }

    texte := StrReplace(imgsBruts[IMG_STATE_INDEX], "**", "")

    if (nbImgs > 1)
    {
        titre := Trim(StrSplit(texte, "`n", "`r")[1])
        msg := wrapped
            ? ("Retour a l'ordonnance d'imagerie 1/" nbImgs " - toutes avaient deja"
                . " ete collees, on recommence.")
            : ("Imagerie " IMG_STATE_INDEX "/" nbImgs " (" titre
                . ") collee dans ce document.")
        ShowCourrierTooltip(msg)
    }

    PasteToField(texte)
    BlockInput(false)
    A_Clipboard := heidiText
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
