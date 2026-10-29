# VJ-13 Paso B: Supresión de avisos de R8 para los reconocedores de scripts no empaquetados
# (chino, devanagari, japonés y coreano). La app solo utiliza el alfabeto latino.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions$Builder
-dontwarn com.google.mlkit.vision.text.korean.KoreanTextRecognizerOptions

# VJ-13 Paso B: ComponentDiscovery (Firebase/ML Kit) instancia las clases que implementan
# ComponentRegistrar por reflexión desde el AndroidManifest.xml. R8 en modo --release
# eliminaba el constructor público sin argumentos <init>(), provocando un NullPointerException
# en tiempo de ejecución al inicializar SharedPrefManager y el motor de OCR.
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
