from pathlib import Path
here = Path(__file__).resolve().parent
text = (here/'run_batch56.py').read_text(encoding='utf-8')
text = text.replace("p.add_argument('--extra',action='append',default=[])", "p.add_argument('--extra',action='append',default=[]);p.add_argument('--ordinary-rng',action='store_true')", 1)
text = text.replace("engine=pathlib.Path(os.environ['LOCALAPPDATA'])", "if a.ordinary_rng:flags=[f for f in flags if not f.startswith('--city-sandbox-seed=')]\nengine=pathlib.Path(os.environ['LOCALAPPDATA'])", 1)
(here/'run_ordinary_batch56.py').write_text(text, encoding='utf-8')
