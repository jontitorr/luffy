import "package:luffy/api/sources/nineanime.dart";
import "package:test/test.dart";

void main() {
  final extractor = NineAnimeExtractor();

  test("Search should yield results", () async {
    final results = await extractor.search("naruto");

    expect(results.length, greaterThan(0));
  });

  test("Get episodes should yield results", () async {
    final results = await extractor.search("naruto");
    final episodes = await extractor.getEpisodes(results.first);

    expect(episodes.length, greaterThan(0));
  });

  test("Get sources should yield results", () async {
    final results = await extractor.search("naruto");
    final episodes = await extractor.getEpisodes(results.first);
    final sources = await extractor.getSources(episodes.first);

    expect(sources.length, greaterThan(0));
  });
}
