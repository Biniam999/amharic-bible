/// Text of a verse ready to show outside the reader: removes the ‹ › marks
/// some KJV editions use around the words of Jesus, and tidies spaces.
String cleanVerseText(String text) =>
    text.replaceAll('‹', '').replaceAll('›', '').replaceAll(RegExp(r'\s+'), ' ').trim();
