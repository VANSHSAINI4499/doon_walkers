import 'package:doon_walkers/features/comments/domain/comment_blocklist_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('commentMatchesBlocklist', () {
    const terms = ['fuck', 'shit', 'bitch', 'asshole', 'bastard', 'cunt'];

    test('matches a blocked term used as a whole word', () {
      expect(commentMatchesBlocklist('this trek was total shit', terms), isTrue);
    });

    test('matches case-insensitively', () {
      expect(commentMatchesBlocklist('SHIT this was hard', terms), isTrue);
      expect(commentMatchesBlocklist('ShIt this was hard', terms), isTrue);
    });

    test('does not match clean text', () {
      expect(commentMatchesBlocklist('This trek was a great classic route!', terms), isFalse);
    });

    test('does not false-positive on an innocent word containing a term as a substring', () {
      // The classic profanity-filter false positive: "classic"/"class"
      // contain "ass" as a raw substring — but "ass" isn't even in this
      // blocklist; the real regression here is any blocked term
      // embedded inside a longer innocent word.
      expect(commentMatchesBlocklist('assassin assessment classic', ['ass']), isFalse);
    });

    test('does not match a blocked term embedded inside a longer word', () {
      expect(commentMatchesBlocklist('assholenot a real word', ['asshole']), isFalse);
    });

    test('matches when the blocked term is its own word even mid-sentence', () {
      expect(commentMatchesBlocklist('you are an asshole honestly', ['asshole']), isTrue);
    });

    test('empty terms list never matches', () {
      expect(commentMatchesBlocklist('shit happens', const []), isFalse);
    });

    test('empty text never matches', () {
      expect(commentMatchesBlocklist('', terms), isFalse);
    });

    test('a term containing regex metacharacters is treated literally', () {
      // RegExp.escape must be applied to the term itself, not just used
      // for word-boundary construction — otherwise an admin-entered
      // term like "a.b" would behave as a wildcard pattern instead of
      // the literal three characters.
      expect(commentMatchesBlocklist('a.b test', ['a.b']), isTrue);
      expect(commentMatchesBlocklist('aXb test', ['a.b']), isFalse);
    });
  });
}
