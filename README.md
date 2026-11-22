# CAGE iPhone + Apple Health Schritt-Sync (v1.5)

Dieses Paket enthält:
- die aktuelle CAGE-Weboberfläche (CAGE.html),
- ein natives SwiftUI/WKWebView-iOS-Projekt,
- eine read-only HealthKit-Anbindung für Schrittzahlen,
- HealthKit Observer Query + Background Delivery (stündliche Anforderung),
- 30 Tage täglichen Schrittverlauf als Rückimport.

## Wichtig
Die bisherige einzelne HTML/PWA-Datei kann auf iOS nicht selbstständig HealthKit lesen und keine garantierte Hintergrundzählung durchführen. Dafür ist die native iOS-App erforderlich.

Dieses Paket ist ein Xcode-Quellprojekt, keine bereits signierte oder installierbare IPA. Es muss auf einem Mac mit Xcode gebaut und mit einem gültigen Apple Developer Team signiert werden. Das HealthKit Capability und Background Delivery müssen für das App Identifier/Provisioning Profile aktiviert sein.

## Build-Schritte auf einem Mac
1. Entpacke das ZIP.
2. Öffne `CAGE.xcodeproj` in Xcode.
3. Wähle das Target `CAGE` → Signing & Capabilities.
4. Wähle dein persönliches Team und prüfe, dass die Bundle-ID `com.hamed.cage` eindeutig ist (ggf. ändere sie).
5. Prüfe, dass die HealthKit Capability sowie HealthKit Background Delivery aktiviert sind. Die Entitlements-Datei ist bereits enthalten; dein Team/Provisioning Profile muss die Berechtigung erlauben.
6. Verbinde dein iPhone, wähle es als Run Destination und starte die App.
7. Öffne in CAGE den Bereich `Stats` und tippe `Apple Health verbinden`. Erlaube das Lesen von `Schritte`.

## Was passiert danach?
- CAGE liest ausschließlich `stepCount` aus Apple Health; es schreibt keine Health-Daten.
- Der heutige Wert wird beim Öffnen/Aktivieren der App aktualisiert.
- Ein HealthKit Observer fragt iOS nach Hintergrundänderungen. Die App fordert stündliche Hintergrundzustellung an; iOS entscheidet über den tatsächlichen Zeitpunkt und kann Updates verzögern.
- Beim ersten Sync wird bis zu 30 Tage täglicher Verlauf eingelesen. Manuell eingetragene historische Tageswerte werden dabei nicht überschrieben.
- Schritte aus iPhone und ggf. Apple Watch können in Apple Health zusammengeführt erscheinen.

## Grenzen von iOS
- Keine sekündliche Echtzeitgarantie im Hintergrund.
- Wenn die App vom Nutzer zwangsweise beendet wird, können Hintergrundzustellungen ausbleiben, bis sie wieder geöffnet wird.
- HealthKit kann Apps aus Datenschutzgründen nicht zuverlässig mitteilen, ob ein Lesezugriff verweigert wurde. Falls keine Werte erscheinen, prüfe: Einstellungen → Datenschutz & Sicherheit → Health → CAGE → Schritte.
- Zum Hintergrund-Sync ist die native, signierte iOS-App erforderlich. Safari/PWA kann nicht direkt HealthKit lesen.

## Datenübernahme aus der bisherigen CAGE-PWA
Die neue native App nutzt ihre eigene WebView-Speicherung. Exportiere in der bisherigen CAGE-App ein JSON-Backup und importiere es in der nativen CAGE-Version, damit deine bisherigen lokalen Einträge übernommen werden. Die bestehende PWA-Datenbank kann nicht automatisch von der nativen App gelesen werden.

## Datenschutz
HealthKit-Zugriff wird erst nach deiner Aktion angefragt. Nur die Schrittzahl wird gelesen. Es wird kein Server und kein Konto verwendet; CAGE speichert die übernommenen Werte lokal in der App-WebView.
