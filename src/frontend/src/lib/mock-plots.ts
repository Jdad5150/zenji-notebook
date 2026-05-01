// Mock SVG plots as data URIs for the notebook prototype
// These simulate matplotlib/seaborn-style chart outputs

function svgToDataUri(svg: string): string {
	return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

const lineChart = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 360" font-family="system-ui, sans-serif">
  <rect width="600" height="360" fill="#1a1b1e" rx="4"/>
  <text x="300" y="28" text-anchor="middle" fill="#cdd6f4" font-size="14" font-weight="600">Training Loss Over Epochs</text>
  <!-- Axes -->
  <line x1="70" y1="40" x2="70" y2="310" stroke="#45475a" stroke-width="1"/>
  <line x1="70" y1="310" x2="570" y2="310" stroke="#45475a" stroke-width="1"/>
  <!-- Grid -->
  <line x1="70" y1="85" x2="570" y2="85" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="70" y1="130" x2="570" y2="130" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="70" y1="175" x2="570" y2="175" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="70" y1="220" x2="570" y2="220" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="70" y1="265" x2="570" y2="265" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <!-- Y labels -->
  <text x="60" y="315" text-anchor="end" fill="#6c7086" font-size="10">0.0</text>
  <text x="60" y="270" text-anchor="end" fill="#6c7086" font-size="10">0.2</text>
  <text x="60" y="225" text-anchor="end" fill="#6c7086" font-size="10">0.4</text>
  <text x="60" y="180" text-anchor="end" fill="#6c7086" font-size="10">0.6</text>
  <text x="60" y="135" text-anchor="end" fill="#6c7086" font-size="10">0.8</text>
  <text x="60" y="90" text-anchor="end" fill="#6c7086" font-size="10">1.0</text>
  <!-- X labels -->
  <text x="70" y="330" text-anchor="middle" fill="#6c7086" font-size="10">0</text>
  <text x="170" y="330" text-anchor="middle" fill="#6c7086" font-size="10">20</text>
  <text x="270" y="330" text-anchor="middle" fill="#6c7086" font-size="10">40</text>
  <text x="370" y="330" text-anchor="middle" fill="#6c7086" font-size="10">60</text>
  <text x="470" y="330" text-anchor="middle" fill="#6c7086" font-size="10">80</text>
  <text x="570" y="330" text-anchor="middle" fill="#6c7086" font-size="10">100</text>
  <!-- Axis labels -->
  <text x="320" y="352" text-anchor="middle" fill="#a6adc8" font-size="11">Epoch</text>
  <text x="18" y="175" text-anchor="middle" fill="#a6adc8" font-size="11" transform="rotate(-90 18 175)">Loss</text>
  <!-- Train loss line (blue) -->
  <polyline fill="none" stroke="#89b4fa" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"
    points="70,75 95,110 120,140 145,165 170,185 195,198 220,210 245,220 270,228 295,235 320,242 345,248 370,253 395,258 420,262 445,266 470,270 495,274 520,278 545,281 570,284"/>
  <!-- Val loss line (pink) -->
  <polyline fill="none" stroke="#f38ba8" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="6,3"
    points="70,80 95,118 120,150 145,172 170,192 195,208 220,218 245,230 270,236 295,244 320,250 345,255 370,260 395,264 420,268 445,272 470,275 495,278 520,282 545,286 570,290"/>
  <!-- Legend -->
  <line x1="400" y1="52" x2="425" y2="52" stroke="#89b4fa" stroke-width="2"/>
  <text x="430" y="56" fill="#cdd6f4" font-size="11">Train</text>
  <line x1="470" y1="52" x2="495" y2="52" stroke="#f38ba8" stroke-width="2" stroke-dasharray="6,3"/>
  <text x="500" y="56" fill="#cdd6f4" font-size="11">Validation</text>
</svg>`;

const barChart = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 360" font-family="system-ui, sans-serif">
  <rect width="600" height="360" fill="#1a1b1e" rx="4"/>
  <text x="300" y="28" text-anchor="middle" fill="#cdd6f4" font-size="14" font-weight="600">Feature Importance</text>
  <!-- Axes -->
  <line x1="120" y1="40" x2="120" y2="310" stroke="#45475a" stroke-width="1"/>
  <line x1="120" y1="310" x2="570" y2="310" stroke="#45475a" stroke-width="1"/>
  <!-- Grid -->
  <line x1="120" y1="310" x2="120" y2="310" stroke="#313244" stroke-width="0.5"/>
  <line x1="232" y1="45" x2="232" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="345" y1="45" x2="345" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="457" y1="45" x2="457" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="570" y1="45" x2="570" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <!-- X labels -->
  <text x="120" y="328" text-anchor="middle" fill="#6c7086" font-size="10">0.0</text>
  <text x="232" y="328" text-anchor="middle" fill="#6c7086" font-size="10">0.1</text>
  <text x="345" y="328" text-anchor="middle" fill="#6c7086" font-size="10">0.2</text>
  <text x="457" y="328" text-anchor="middle" fill="#6c7086" font-size="10">0.3</text>
  <text x="570" y="328" text-anchor="middle" fill="#6c7086" font-size="10">0.4</text>
  <!-- Axis label -->
  <text x="345" y="352" text-anchor="middle" fill="#a6adc8" font-size="11">Importance Score</text>
  <!-- Bars (horizontal) -->
  <text x="115" y="65" text-anchor="end" fill="#cdd6f4" font-size="11">income</text>
  <rect x="120" y="52" width="405" height="22" rx="2" fill="#89b4fa" opacity="0.85"/>
  <text x="115" y="100" text-anchor="end" fill="#cdd6f4" font-size="11">age</text>
  <rect x="120" y="87" width="338" height="22" rx="2" fill="#89b4fa" opacity="0.75"/>
  <text x="115" y="135" text-anchor="end" fill="#cdd6f4" font-size="11">score</text>
  <rect x="120" y="122" width="270" height="22" rx="2" fill="#89b4fa" opacity="0.65"/>
  <text x="115" y="170" text-anchor="end" fill="#cdd6f4" font-size="11">tenure</text>
  <rect x="120" y="157" width="225" height="22" rx="2" fill="#89b4fa" opacity="0.55"/>
  <text x="115" y="205" text-anchor="end" fill="#cdd6f4" font-size="11">balance</text>
  <rect x="120" y="192" width="180" height="22" rx="2" fill="#89b4fa" opacity="0.5"/>
  <text x="115" y="240" text-anchor="end" fill="#cdd6f4" font-size="11">products</text>
  <rect x="120" y="227" width="112" height="22" rx="2" fill="#89b4fa" opacity="0.4"/>
  <text x="115" y="275" text-anchor="end" fill="#cdd6f4" font-size="11">region</text>
  <rect x="120" y="262" width="67" height="22" rx="2" fill="#89b4fa" opacity="0.35"/>
  <text x="115" y="305" text-anchor="end" fill="#cdd6f4" font-size="11">gender</text>
  <rect x="120" y="292" width="22" height="22" rx="2" fill="#89b4fa" opacity="0.3"/>
</svg>`;

const scatterPlot = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 600 360" font-family="system-ui, sans-serif">
  <rect width="600" height="360" fill="#1a1b1e" rx="4"/>
  <text x="300" y="28" text-anchor="middle" fill="#cdd6f4" font-size="14" font-weight="600">Score vs Income (by Cluster)</text>
  <!-- Axes -->
  <line x1="70" y1="40" x2="70" y2="310" stroke="#45475a" stroke-width="1"/>
  <line x1="70" y1="310" x2="570" y2="310" stroke="#45475a" stroke-width="1"/>
  <!-- Grid -->
  <line x1="70" y1="85" x2="570" y2="85" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="70" y1="175" x2="570" y2="175" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="70" y1="265" x2="570" y2="265" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="195" y1="40" x2="195" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="320" y1="40" x2="320" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <line x1="445" y1="40" x2="445" y2="310" stroke="#313244" stroke-width="0.5" stroke-dasharray="4"/>
  <!-- Axis labels -->
  <text x="320" y="352" text-anchor="middle" fill="#a6adc8" font-size="11">Income ($k)</text>
  <text x="18" y="175" text-anchor="middle" fill="#a6adc8" font-size="11" transform="rotate(-90 18 175)">Score</text>
  <!-- Cluster 0 (blue) -->
  <circle cx="120" cy="250" r="4" fill="#89b4fa" opacity="0.7"/><circle cx="135" cy="240" r="4" fill="#89b4fa" opacity="0.7"/>
  <circle cx="150" cy="260" r="4" fill="#89b4fa" opacity="0.7"/><circle cx="160" cy="235" r="4" fill="#89b4fa" opacity="0.7"/>
  <circle cx="140" cy="270" r="4" fill="#89b4fa" opacity="0.7"/><circle cx="175" cy="245" r="4" fill="#89b4fa" opacity="0.7"/>
  <circle cx="130" cy="255" r="4" fill="#89b4fa" opacity="0.7"/><circle cx="155" cy="230" r="4" fill="#89b4fa" opacity="0.7"/>
  <circle cx="145" cy="265" r="4" fill="#89b4fa" opacity="0.7"/><circle cx="165" cy="250" r="4" fill="#89b4fa" opacity="0.7"/>
  <circle cx="125" cy="275" r="4" fill="#89b4fa" opacity="0.7"/><circle cx="180" cy="238" r="4" fill="#89b4fa" opacity="0.7"/>
  <!-- Cluster 1 (green) -->
  <circle cx="280" cy="160" r="4" fill="#a6e3a1" opacity="0.7"/><circle cx="300" cy="145" r="4" fill="#a6e3a1" opacity="0.7"/>
  <circle cx="320" cy="170" r="4" fill="#a6e3a1" opacity="0.7"/><circle cx="290" cy="155" r="4" fill="#a6e3a1" opacity="0.7"/>
  <circle cx="310" cy="140" r="4" fill="#a6e3a1" opacity="0.7"/><circle cx="335" cy="165" r="4" fill="#a6e3a1" opacity="0.7"/>
  <circle cx="275" cy="175" r="4" fill="#a6e3a1" opacity="0.7"/><circle cx="305" cy="150" r="4" fill="#a6e3a1" opacity="0.7"/>
  <circle cx="325" cy="135" r="4" fill="#a6e3a1" opacity="0.7"/><circle cx="295" cy="168" r="4" fill="#a6e3a1" opacity="0.7"/>
  <circle cx="340" cy="158" r="4" fill="#a6e3a1" opacity="0.7"/><circle cx="285" cy="148" r="4" fill="#a6e3a1" opacity="0.7"/>
  <!-- Cluster 2 (peach) -->
  <circle cx="440" cy="80" r="4" fill="#fab387" opacity="0.7"/><circle cx="460" cy="95" r="4" fill="#fab387" opacity="0.7"/>
  <circle cx="480" cy="70" r="4" fill="#fab387" opacity="0.7"/><circle cx="450" cy="85" r="4" fill="#fab387" opacity="0.7"/>
  <circle cx="470" cy="100" r="4" fill="#fab387" opacity="0.7"/><circle cx="500" cy="75" r="4" fill="#fab387" opacity="0.7"/>
  <circle cx="435" cy="90" r="4" fill="#fab387" opacity="0.7"/><circle cx="490" cy="65" r="4" fill="#fab387" opacity="0.7"/>
  <circle cx="455" cy="78" r="4" fill="#fab387" opacity="0.7"/><circle cx="510" cy="88" r="4" fill="#fab387" opacity="0.7"/>
  <circle cx="475" cy="72" r="4" fill="#fab387" opacity="0.7"/><circle cx="445" cy="98" r="4" fill="#fab387" opacity="0.7"/>
  <!-- Legend -->
  <circle cx="400" cy="52" r="4" fill="#89b4fa"/><text x="410" y="56" fill="#cdd6f4" font-size="10">Cluster 0</text>
  <circle cx="470" cy="52" r="4" fill="#a6e3a1"/><text x="480" y="56" fill="#cdd6f4" font-size="10">Cluster 1</text>
  <circle cx="540" cy="52" r="4" fill="#fab387"/><text x="550" y="56" fill="#cdd6f4" font-size="10">Cluster 2</text>
</svg>`;

export const mockPlots = {
	lineChart: svgToDataUri(lineChart),
	barChart: svgToDataUri(barChart),
	scatterPlot: svgToDataUri(scatterPlot)
};
