// Builds paper/TurAIsta_AIETR.docx from paper/manuscript.md in the TurAIsmo layout.
// Run: NODE_PATH=<dir with node_modules/docx> node paper/build_docx.js
const fs = require('fs');
const path = require('path');
const {
  AlignmentType, BorderStyle, Document, ExternalHyperlink, Footer, ImageRun, LevelFormat,
  Packer, PageNumber, Paragraph, Table, TableCell, TableRow, TextRun, WidthType,
} = require('docx');

const DIR = __dirname;
const md = fs.readFileSync(path.join(DIR, 'manuscript.md'), 'utf8').replace(/\r/g, '');
const FONT = 'Times New Roman';
const TEXT_WIDTH = 9360; // 6.5 in in DXA
const BODY = { line: 276, after: 120 }; // 1.15 lines

// Inline markdown: **bold**, *italic*, `code`, and bare URLs.
function runs(text, base = {}) {
  const out = [];
  const re = /(\*\*[^*]+\*\*|\*[^*]+\*|`[^`]+`|https?:\/\/[^\s)]+)/g;
  let last = 0;
  let m;
  while ((m = re.exec(text))) {
    if (m.index > last) out.push(new TextRun({ text: text.slice(last, m.index), font: FONT, ...base }));
    const tok = m[0];
    if (tok.startsWith('**')) out.push(new TextRun({ text: tok.slice(2, -2), font: FONT, ...base, bold: true }));
    else if (tok.startsWith('`')) out.push(new TextRun({ text: tok.slice(1, -1), font: FONT, ...base }));
    else if (tok.startsWith('*')) out.push(new TextRun({ text: tok.slice(1, -1), font: FONT, ...base, italics: true }));
    else {
      const url = tok.replace(/[.,;]$/, '');
      out.push(new ExternalHyperlink({
        link: url,
        children: [new TextRun({ text: url, font: FONT, ...base, style: 'Hyperlink' })],
      }));
      if (url.length < tok.length) out.push(new TextRun({ text: tok.slice(url.length), font: FONT, ...base }));
    }
    last = m.index + tok.length;
  }
  if (last < text.length) out.push(new TextRun({ text: text.slice(last), font: FONT, ...base }));
  return out;
}

function pngSize(file) {
  const b = fs.readFileSync(file);
  return { w: b.readUInt32BE(16), h: b.readUInt32BE(20) };
}

const rule = { style: BorderStyle.SINGLE, size: 8, color: '000000' };
const none = { style: BorderStyle.NONE, size: 0, color: 'FFFFFF' };

function table(lines) {
  const rows = lines
    .filter((l) => !/^\|\s*-/.test(l))
    .map((l) => l.replace(/^\||\|$/g, '').split('|').map((c) => c.trim()));
  const n = rows[0].length;
  const len = Array.from({ length: n }, (_, j) => Math.max(...rows.map((r) => (r[j] || '').length)));
  const weight = len.map((x) => Math.max(8, Math.min(x, 60)));
  const total = weight.reduce((a, b) => a + b, 0);
  const widths = weight.map((w) => Math.floor((w / total) * TEXT_WIDTH));
  widths[n - 1] += TEXT_WIDTH - widths.reduce((a, b) => a + b, 0);
  return new Table({
    width: { size: TEXT_WIDTH, type: WidthType.DXA },
    columnWidths: widths,
    rows: rows.map((r, i) => new TableRow({
      cantSplit: true,
      tableHeader: i === 0,
      children: r.map((c, j) => new TableCell({
        width: { size: widths[j], type: WidthType.DXA },
        margins: { top: 40, bottom: 40, left: 80, right: 80 },
        borders: {
          top: i === 0 ? rule : none,
          bottom: i === 0 || i === rows.length - 1 ? rule : none,
          left: none,
          right: none,
        },
        children: [new Paragraph({
          spacing: { after: 0, line: 240 },
          keepNext: i < rows.length - 1,
          children: runs(c, { size: 20, bold: i === 0 }),
        })],
      })),
    })),
  });
}

const children = [];
const lines = md.split('\n');
let section = '';
let listInstance = 0;
let inList = false;
let i = 0;

// Title block: '# Title', then affiliation, authors, emails until '## Abstract'.
const title = lines[i++].replace(/^#\s+/, '');
children.push(new Paragraph({
  alignment: AlignmentType.CENTER,
  spacing: { after: 160 },
  children: [new TextRun({ text: title, font: FONT, size: 32, bold: true })],
}));
while (!lines[i].startsWith('## ')) {
  const l = lines[i++].trim();
  if (!l) continue;
  if (l.includes('@')) {
    const parts = l.split(/,\s*/);
    const kids = [];
    parts.forEach((p, k) => {
      if (k) kids.push(new TextRun({ text: ', ', font: FONT, size: 20 }));
      if (/^[\w.+-]+@[\w.-]+$/.test(p)) {
        kids.push(new ExternalHyperlink({
          link: `mailto:${p}`,
          children: [new TextRun({ text: p, font: FONT, size: 20, style: 'Hyperlink' })],
        }));
      } else kids.push(new TextRun({ text: p, font: FONT, size: 20 }));
    });
    children.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 240 }, children: kids }));
  } else {
    children.push(new Paragraph({
      alignment: AlignmentType.CENTER, spacing: { after: 60 }, children: runs(l, { size: 24 }),
    }));
  }
}

for (; i < lines.length; i++) {
  const l = lines[i];
  if (!l.trim()) { inList = false; continue; }

  if (l.startsWith('## ')) {
    section = l.slice(3).trim();
    children.push(new Paragraph({
      spacing: { before: 240, after: 120 }, keepNext: true,
      children: [new TextRun({ text: section, font: FONT, size: 28, bold: true })],
    }));
    continue;
  }
  if (l.startsWith('### ')) {
    children.push(new Paragraph({
      spacing: { before: 180, after: 80 }, keepNext: true,
      children: [new TextRun({ text: l.slice(4).trim(), font: FONT, size: 24, bold: true })],
    }));
    continue;
  }
  if (l.startsWith('|')) {
    const block = [];
    while (i < lines.length && lines[i].startsWith('|')) block.push(lines[i++]);
    i--;
    children.push(table(block));
    children.push(new Paragraph({ spacing: { after: 120 }, children: [] }));
    continue;
  }
  const img = l.match(/^!\[\]\((.+)\)$/);
  if (img) {
    const file = path.join(DIR, img[1]);
    const { w, h } = pngSize(file);
    // Natural size of a 300 dpi PNG at 96 px per inch, capped at the 6.25 in text width.
    const width = Math.min(600, Math.round((w / 300) * 96 * 1.1));
    children.push(new Paragraph({
      alignment: AlignmentType.CENTER, keepNext: true, spacing: { before: 120, after: 60 },
      children: [new ImageRun({
        type: 'png', data: fs.readFileSync(file),
        transformation: { width, height: Math.round((h / w) * width) },
      })],
    }));
    continue;
  }
  if (/^\*\*Figure \d+\.\*\*/.test(l)) {
    children.push(new Paragraph({
      alignment: AlignmentType.JUSTIFIED, spacing: { after: 200, line: 240 },
      children: runs(l, { size: 20 }),
    }));
    continue;
  }
  if (/^\*Table \d+\./.test(l)) {
    children.push(new Paragraph({
      keepNext: true, spacing: { before: 120, after: 60 },
      children: runs(l, { size: 20 }),
    }));
    continue;
  }
  const li = l.match(/^\d+\.\s+(.*)$/);
  if (li) {
    if (!inList) { listInstance++; inList = true; }
    children.push(new Paragraph({
      numbering: { reference: 'ordered', level: 0, instance: listInstance },
      alignment: AlignmentType.JUSTIFIED, spacing: BODY,
      children: runs(li[1], { size: 24 }),
    }));
    continue;
  }
  if (section === 'References') {
    children.push(new Paragraph({
      indent: { left: 720, hanging: 720 }, spacing: { after: 120, line: 240 },
      children: runs(l, { size: 24 }),
    }));
    continue;
  }
  children.push(new Paragraph({
    alignment: AlignmentType.JUSTIFIED, spacing: BODY, children: runs(l, { size: 24 }),
  }));
}

const doc = new Document({
  creator: 'TurAIsta team',
  title,
  styles: { default: { document: { run: { font: FONT, size: 24 } } } },
  numbering: {
    config: [{
      reference: 'ordered',
      levels: [{
        level: 0, format: LevelFormat.DECIMAL, text: '%1.', alignment: AlignmentType.LEFT,
        style: { paragraph: { indent: { left: 720, hanging: 360 } } },
      }],
    }],
  },
  sections: [{
    properties: {
      page: {
        size: { width: 12240, height: 15840 },
        margin: { top: 1440, bottom: 1440, left: 1440, right: 1440 },
      },
    },
    footers: {
      default: new Footer({
        children: [new Paragraph({
          alignment: AlignmentType.CENTER,
          children: [new TextRun({ children: [PageNumber.CURRENT], font: FONT, size: 20 })],
        })],
      }),
    },
    children,
  }],
});

Packer.toBuffer(doc).then((buf) => {
  const out = path.join(DIR, process.argv[2] || 'TurAIsta_AIETR.docx');
  fs.writeFileSync(out, buf);
  console.log('wrote', out);
});
