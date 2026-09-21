with open('api/static/index.html', 'r', encoding='utf-8') as f:
    html = f.read()

old_logic = "title.includes('Quality Control') || \n                                          title.includes('Trimming') || \n                                          title.includes('Contamination') || \n                                          title.includes('Assembly & Polishing') || \n                                          title.includes('Scaffolding')"
new_logic = "title.includes('Raw Read QC') || \n                                          title.includes('Trimming') || \n                                          title.includes('Contamination') || \n                                          title.includes('Assembly') || \n                                          title.includes('Scaffolding')"

html = html.replace(old_logic, new_logic)

with open('api/static/index.html', 'w', encoding='utf-8') as f:
    f.write(html)
print('Fixed isPreAssembly logic')
