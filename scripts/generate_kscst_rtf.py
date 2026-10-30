import os

md_path = os.path.join(os.path.dirname(__file__), "..", "KSCST_50th_Series_Proposal_Filled_VehiCare.md")
workspace_rtf = os.path.join(os.path.dirname(__file__), "..", "KSCST_50th_Series_VehiCare_Filled_Proposal.rtf")

with open(md_path, "r", encoding="utf-8") as f:
    lines = f.readlines()

rtf = [r"{\rtf1\ansi\ansicpg1252\deff0\nouicompat\deflang1033{\fonttbl{\f0\froman\fcharset0 Times New Roman;}{\f1\fnil\fcharset0 Calibri;}}",
       r"{\colortbl ;\red0\green51\blue102;\red51\green51\blue51;\red180\green0\blue0;}",
       r"\viewkind4\uc1\pard\f0\fs24 "]

for line in lines:
    line_clean = line.strip()
    if not line_clean:
        rtf.append(r"\par\par ")
        continue
    
    if line_clean.startswith("# "):
        title = line_clean.replace("# ", "").replace("**", "")
        rtf.append(r"\par\b\cf1\fs28 " + title + r"\cf0\b0\fs24\par ")
    elif line_clean.startswith("## "):
        title = line_clean.replace("## ", "").replace("**", "")
        rtf.append(r"\par\b\cf1\fs26 " + title + r"\cf0\b0\fs24\par ")
    elif line_clean.startswith("### "):
        title = line_clean.replace("### ", "").replace("**", "")
        rtf.append(r"\par\b\cf2\fs24 " + title + r"\b0\par ")
    elif line_clean.startswith("|") and line_clean.endswith("|"):
        cols = [c.strip() for c in line_clean.strip("|").split("|")]
        if all(set(c).issubset({"-", ":", " "}) for c in cols):
            continue
        row_text = r"\par\b " + "   |   ".join(cols) + r"\b0 "
        rtf.append(row_text.replace("**", ""))
    else:
        parts = line_clean.split("**")
        formatted = ""
        for idx, part in enumerate(parts):
            if idx % 2 == 1:
                formatted += r"\b " + part + r"\b0 "
            else:
                formatted += part
        rtf.append(formatted + r"\par ")

rtf.append(r"\par}")

with open(workspace_rtf, "w", encoding="utf-8") as out:
    out.write("".join(rtf))

print(f"RTF proposal successfully saved to: {workspace_rtf}")
