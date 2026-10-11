"""Recover all five original tests from the checked-in Flash source catalog.

No Flash runtime. Questions, answer IDs, branches, weights and result copy
remain traceable to TestStartMov.as and ResultBad.as.
"""
import csv, json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STRING = r'"(?:[^"\\]|\\.)*"'

# Correct only clear spelling errors; retain the original wording and tone.
SPELLING_FIXES = {
    'выностлив': 'вынослив',
    'тейквандо': 'тхэквондо',
    'дествия': 'действия',
    'воообще': 'вообще',
    'взволится': 'взводится',
    'имено': 'именно',
}

def correct_spelling(text):
    return re.sub(r'\b(' + '|'.join(SPELLING_FIXES) + r')\b',
                  lambda match: SPELLING_FIXES[match[0]], text)

# Editorial risk points for test II, in the original answer order.
# Lower is better; retain the original verdict thresholds. Self-assessment
# stays playable but does not contribute to the result.
TEST2_POINTS = {
    1: [2, 1, 2, 3, 2, 0, 2, 3],
    2: [2, 3, 2, 0, 1, 2, 2, 1],
    3: [2, 1, 0, 1, 2, 2, 3, 1],
    4: [2, 3, 3, 2],
    5: [1, 1, 2, 1, 1, 3, 2, 1],
    6: [1, 1, 3, 2, 2, 1, 2, 0],
    7: [2, 2, 1, 1, 3, 1, 0],
    8: [2, 0, 2, 0, 1, 1, 3, 2],
    9: [0, 1, 1, 0, 2, 2, 1, 3],
    10: [0, 0, 0, 0],
}

def brace(source, pos):
    depth = 0
    quoted = escaped = False
    for end in range(pos, len(source)):
        c = source[end]
        if quoted:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == '"': quoted = False
        elif c == '"': quoted = True
        elif c == '{': depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0: return source[pos+1:end]
    raise ValueError('Unclosed ActionScript block')

def function(source, name):
    start = re.search(r'function '+name+r'\(', source).end()
    return brace(source, source.index('{', start))

def cases(source):
    markers = list(re.finditer(r'\bcase (\d+):', source))
    return {int(m[1]): source[m.end():markers[i+1].start() if i+1<len(markers) else len(source)] for i,m in enumerate(markers)}

def strings(source):
    return [json.loads(m[0]) for m in re.finditer(STRING, source)]

def assigned(source, lhs):
    return json.loads(re.search(re.escape(lhs)+r'\s*=\s*('+STRING+r')', source)[1])

def array(source, lhs, vector=False):
    pattern = re.escape(lhs)+ (r'\s*=\s*new <String>\[(.*?)\];' if vector else r'\s*=\s*new Array\((.*?)\);')
    raw=re.search(pattern,source,re.S)[1]
    return strings(raw) if vector else json.loads('['+raw+']')

def build():
    source = json.loads((ROOT/'data/flash_catalog.json').read_text())['actionscript']
    test, result = source['TestStartMov.as'], source['ResultBad.as']
    starts = cases(function(test,'StartTest'))
    texts = array(result,'this.ResultArr',True)
    labels = array(result,'this.ResultFotTests',True)
    table = {}
    def loc(key, value):
        table['tests.'+key] = correct_spelling(value)
        return '@loc:tests.'+key
    tests = []
    for number, count in [(1,16),(2,10),(3,15),(4,9),(5,14)]:
        entry = {'id':number,'source':'TestStartMov.as / TextSwitcher%d'%number,
                 'initial_score':35 if number==4 else 0,'questions':{}}
        switch = function(test,'TextSwitcher%d'%number)
        transitions = cases(switch)
        points = array(starts[number],'this.pointsArr') if number>=3 else None
        hints = array(starts[number],'this.hintsBase') if number in [3,5] else None
        if number==1:
            questions = {1:assigned(starts[1],'this.Txt.text')}
            for block in transitions.values():
                for m in re.finditer(r'this.QuestInts\[0\] = (\d+);\s*this.Txt.text = ('+STRING+r');',block):
                    questions[int(m[1])] = json.loads(m[2])
            for q in range(1,17):
                block = transitions[q]
                pos = block.index('{',block.index('if('))
                yes = brace(block,pos)
                no = brace(block,block.index('{',block.index('else',pos+len(yes)+2)))
                options = []
                for choice, branch in [(1,yes),(5,no)]:
                    final = re.search(r'new ResultBad\((\d+)\)',branch)
                    options.append({'id':choice,'text':loc('test1.answer%d'%choice,assigned(starts[1],'this.Choose%d.Txt.text'%choice)),
                                    'result_id':int(final[1])} if final else
                                   {'id':choice,'text':loc('test1.answer%d'%choice,assigned(starts[1],'this.Choose%d.Txt.text'%choice)),
                                    'next':int(re.search(r'this.QuestInts\[0\] = (\d+)',branch)[1])})
                entry['questions'][str(q)] = {'text':loc('test1.question%d'%q,questions[q]),'options':options}
        else:
            for q in range(1,count+1):
                block = starts[number] if q==1 else transitions[q-1]
                question = {'text':loc('test%d.question%d'%(number,q),assigned(block,'this.Txt.text')),'options':[]}
                for m in re.finditer(r'this.Choose(\d).Txt.text = ('+STRING+r');',block):
                    choice = int(m[1])
                    score = points[q-1][choice-1] if points else TEST2_POINTS[q][len(question['options'])]
                    question['options'].append({'id':choice,'text':loc('test%d.question%d.answer%d'%(number,q,choice),json.loads(m[2])),'points':score})
                if hints: question['hint']=loc('test%d.question%d.hint'%(number,q),hints[q-1])
                if number == 2: question['scored'] = q != 10
                assert question['options'], (number,q)
                entry['questions'][str(q)]=question
        tests.append(entry)
    outcomes = {}
    for rid in range(12,33):
        outcomes[str(rid)] = {'label':loc('result%d.label'%rid,labels[rid-12]),'text':loc('result%d.text'%rid,texts[rid-1])}
    result_cases=cases(function(result,'OnAdded'))
    # Case 47 is followed by 50; case grouping is irrelevant for these three.
    for rid in [50,150]:
        outcomes[str(rid)]=[loc('result%d.text%d'%(rid,i),json.loads(m[1])) for i,m in enumerate(re.finditer(r'this.Mov.Rezt.Txt.text = ('+STRING+r');',result_cases[rid]))]
    analogs=array(function(test,'TextSwitcher4'),'_loc2_')
    durations=array(result_cases[100],'_loc3_')
    outcomes['100']=[{'duration':loc('result100.duration%d'%i,durations[i*2]+' '+durations[i*2+1]),
                      'text':loc('result100.text%d'%i,text),
                      'analog':loc('result100.analog%d'%i,analogs[i])} for i,text in enumerate(array(result_cases[100],'_loc4_'))]
    ui={'question':'Вопрос {number}','question_of':'Вопрос {number} из {total}',
        'menu':'Главное меню','restart':'Начать заново','continue':'Продолжить',
        'result':'Результат теста','outcome':'Итог: {value}',
        'advice':'Рекомендации и советы:','analog':'Ваш кинематографический аналог:',
        'no_advice':'Рекомендаций и советов нет.','no_hints':'Вы определенно не нуждаетесь в советах!',
        'last_result':'Последний результат: {value}','absent':'отсутствует'}
    for key,value in ui.items():loc('ui.'+key,value)
    (ROOT/'data/tests.json').write_text(json.dumps({'tests':tests,'outcomes':outcomes},ensure_ascii=False,indent=2)+'\n')
    with (ROOT/'locales/tests.csv').open('w',newline='') as f:
        writer=csv.writer(f);writer.writerow(['key','ru','en'])
        writer.writerows((k,v,'') for k,v in table.items())
    selectors=json.loads((ROOT/'data/selectors.json').read_text())
    n=0
    for entry in selectors:
        if entry['kind']=='tests':n+=1;entry.update(available=True,test_id=n)
    (ROOT/'data/selectors.json').write_text(json.dumps(selectors,ensure_ascii=False,indent=2)+'\n')
    print('Recovered', [len(t['questions']) for t in tests], 'questions;',len(table),'localized strings')

if __name__=='__main__':build()
