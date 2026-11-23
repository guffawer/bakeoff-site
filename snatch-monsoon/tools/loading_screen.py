"""Adds the still frame, a styled progress bar and a short note to Godot's exported index.html."""
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8").read()
css = """
#status { background: #0b0d10 url(still/still.jpg) center / cover no-repeat !important; justify-content: flex-end !important; }
#status::before { content: ""; position: absolute; inset: 0; background: linear-gradient(to top, rgba(11,13,16,.92) 0%, rgba(11,13,16,.35) 40%, rgba(11,13,16,.15) 100%); }
#status-progress { position: relative !important; bottom: auto !important; width: 70% !important; height: 8px; margin: 0 auto 10px !important; appearance: none; -webkit-appearance: none; border: 0; border-radius: 4px; background: rgba(255,255,255,.18); overflow: hidden; }
#status-progress::-webkit-progress-bar { background: rgba(255,255,255,.18); }
#status-progress::-webkit-progress-value { background: #ff6b0a; }
#status-progress::-moz-progress-bar { background: #ff6b0a; }
#load-note { position: relative; color: #e6e3da; font: 15px/1.4 -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; text-align: center; margin: 0 16px 12%; }
#load-note small { display: block; color: #9aa0a6; font-size: 13px; margin-top: 2px; }
"""
note = '<div id="load-note">Loading the game engine, about 10 MB<small>Build 4  ·  faster after the first visit</small></div>'
if "load-note" not in s:
    s = s.replace("</style>", css + "</style>", 1)
    s = s.replace('<div id="status-notice"></div>', '<div id="status-notice"></div>\n\t\t\t' + note, 1)
    s = s.replace("setStatusMode('progress');", "setStatusMode('progress'); statusProgress.style.display = 'block';", 1)
open(p, "w", encoding="utf-8").write(s)
print("loading screen added")
