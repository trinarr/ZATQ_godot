"""Regression coverage for caption visibility and alpha independence and preserved timing."""
import copy
import unittest
from normalize_caption_entrances import normalize_intro, migrate


def track(alpha):
    return {'anchors': {'caption': [1, 0, 0, 1, 10, 20]},
            'intro': [[['caption', [1, 0, 0, 1, i, 20], [1, 1, 1, a, 0, 0, 0]]] for i, a in enumerate(alpha)],
            'outro': [[['caption', [1, 0, 0, 1, 0, 20], [1, 1, 1, 1, 0, 0, 0]]]]}


class CaptionEntranceTests(unittest.TestCase):
    def test_correct_prefix_and_preserve_fade_and_geometry(self):
        source = track([1, 1, 0, .328125, .66015625, 1])
        expected = copy.deepcopy(source)
        for row in expected['intro'][:2]: row[0].append(False)
        self.assertEqual(normalize_intro(source), ['caption'])
        self.assertEqual(source, expected)
        self.assertEqual(normalize_intro(source), [])

    def test_normal_fades_and_intentional_flashes_unchanged(self):
        for values in [[0, .5, 1], [1, 1, 1], [1, 0, 1],
                       [0, .5, 1, 0, .5, 1], [1, .5, 0, .5, 1],
                       [1, 0, .5, .25, 1], [1, 0, .5]]:
            with self.subTest(values=values):
                source = track(values); before = copy.deepcopy(source)
                self.assertEqual(normalize_intro(source), [])
                self.assertEqual(source, before)

    def test_missing_record_does_not_create_fake_fade(self):
        source = track([1, 0, .5, 1]);source['intro'][2] = []
        before = copy.deepcopy(source)
        self.assertEqual(normalize_intro(source), [])
        self.assertEqual(source, before)

    def test_other_text_and_outro_preserved(self):
        source = track([1, 0, .5, 1])
        other = ['other', [1, 0, 0, 1, 0, 0], [1, 1, 1, 1, 0, 0, 0]]
        source['anchors']['other'] = [1, 0, 0, 1, 0, 0]
        for row in source['intro']: row.append(copy.deepcopy(other))
        before = copy.deepcopy(source)
        normalize_intro(source)
        self.assertEqual(source['outro'], before['outro'])
        self.assertEqual([row[1] for row in source['intro']], [row[1] for row in before['intro']])

    def test_runtime_catalogs_are_clean(self):
        self.assertEqual(migrate(check=True), 0)



if __name__ == '__main__': unittest.main()
