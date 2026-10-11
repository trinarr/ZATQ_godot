"""Independent completeness checks against the original ActionScript."""
import csv, json, re, unittest
from pathlib import Path
from build_tests_content import correct_spelling
ROOT=Path(__file__).resolve().parents[1]
STRING=r'"(?:[^"\\]|\\.)*"'
class OriginalTests(unittest.TestCase):
    def setUp(self):
        self.flash=json.loads((ROOT/'data/flash_catalog.json').read_text())['actionscript']
        self.flash={name:correct_spelling(text) for name,text in self.flash.items()}
        self.data=json.loads((ROOT/'data/tests.json').read_text())
        with (ROOT/'locales/tests.csv').open() as f:self.locale={r['key']:r['ru'] for r in csv.DictReader(f)}
    def resolve(self,value):return self.locale[value.removeprefix('@loc:')]
    def test_questions_and_answers_are_complete(self):
        source=self.flash['TestStartMov.as']
        questions={json.loads(m[1]) for m in re.finditer(r'this.Txt.text = ('+STRING+r');',source)}
        copied={self.resolve(q['text']) for t in self.data['tests'] for q in t['questions'].values()}
        self.assertEqual(questions,copied)
        answers={json.loads(m[1]) for m in re.finditer(r'this.Choose\d.Txt.text = ('+STRING+r');',source)}
        copied={self.resolve(a['text']) for t in self.data['tests'] for q in t['questions'].values() for a in q['options']}
        self.assertEqual(answers,copied)
        self.assertEqual([len(t['questions']) for t in self.data['tests']],[16,10,15,9,14])
    def test_original_numeric_weights(self):
        rows=[json.loads('['+m[1]+']') for m in re.finditer(r'this.pointsArr = new Array\((.*?)\);',self.flash['TestStartMov.as'],re.S)]
        for test,source in zip(self.data['tests'][2:],rows):
            for n,q in enumerate(test['questions'].values()):
                self.assertEqual([a['points'] for a in q['options']],source[n])
    def test_second_test_explicit_scoring(self):
        questions=self.data['tests'][1]['questions']
        for key,q in questions.items():
            self.assertEqual(q['scored'],key!='10')
            for answer in q['options']:
                self.assertIsInstance(answer['points'],int)
                self.assertIn(answer['points'],range(4))
        self.assertEqual([a['points'] for a in questions['10']['options']],[0,0,0,0])
        # Same button position has different weights across questions.
        self.assertGreater(len({questions[str(q)]['options'][3]['points'] for q in range(1,10)}),1)
    def test_recommendations_and_result_copy(self):
        source=self.flash['TestStartMov.as']
        hints={json.loads(m[0]) for a in re.finditer(r'this.hintsBase = new Array\((.*?)\);',source,re.S) for m in re.finditer(STRING,a[1])}
        copied={self.resolve(q['hint']) for t in self.data['tests'] for q in t['questions'].values() if 'hint' in q}
        self.assertEqual(hints,copied)
        for key,text in self.locale.items():
            if re.match(r'tests.result\d',key):
                # Durations combine adjacent original strings into one label.
                if '.duration' not in key:self.assertTrue(json.dumps(text,ensure_ascii=False) in self.flash['ResultBad.as']+source,key)
    def test_assets_are_not_empty(self):
        from PIL import Image
        for key in ['question','menu_icon','restart_icon','continue_icon']:
            with Image.open(ROOT/'assets/flash_ui'/('tests_'+key+'.png')) as im:self.assertIsNotNone(im.getbbox())
if __name__=='__main__':unittest.main()
