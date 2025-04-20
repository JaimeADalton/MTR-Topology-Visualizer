#!/bin/bash

# === Script para Desplegar el Frontend de MTR Topology Visualizer ===

# --- Configuración ---
DEFAULT_INSTALL_DIR="/opt/mtr-topology"
INSTALL_DIR="${1:-$DEFAULT_INSTALL_DIR}" # Usar argumento o default
APP_USER="mtrtopology" # Usuario esperado si se instala en /opt
APP_GROUP="mtrtopology" # Grupo esperado si se instala en /opt

# --- Colores y Funciones ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m';
print_message() { echo -e "${GREEN}INFO:${NC} $1"; }
print_warning() { echo -e "${YELLOW}WARN:${NC} $1"; }
print_error() { echo -e "${RED}ERROR:${NC} $1"; }

# --- Verificación de Root (Solo si se instala en /opt) ---
if [[ "$INSTALL_DIR" == "/opt/"* ]] && [ "$EUID" -ne 0 ]; then
    print_error "Necesitas ejecutar como root (sudo) para instalar en $INSTALL_DIR"
    exit 1
fi

print_message "Desplegando archivos del Frontend en: $INSTALL_DIR"
print_message "==============================================="

# --- Crear Estructura de Directorios del Frontend ---
print_message "Creando directorios necesarios..."
mkdir -p "$INSTALL_DIR/web/static/css" || { print_error "Fallo al crear directorios CSS"; exit 1; }
mkdir -p "$INSTALL_DIR/web/static/js" || { print_error "Fallo al crear directorios JS"; exit 1; }
mkdir -p "$INSTALL_DIR/web/templates" || { print_error "Fallo al crear directorios Templates"; exit 1; }
# mkdir -p "$INSTALL_DIR/web/static/img" # Opcional si añades favicon

# --- Crear Archivos con Heredoc ---

# 1. CSS
print_message "Creando web/static/css/style.css..."
cat << 'EOF' > "$INSTALL_DIR/web/static/css/style.css"
/* Base and Reset */
:root {
    --color-bg-primary: #1a202c;
    --color-bg-secondary: #2d3748;
    --color-bg-tertiary: #4a5568;
    --color-bg-accent: #3182ce;
    --color-text-primary: #e2e8f0;
    --color-text-secondary: #a0aec0;
    --color-text-accent: #4299e1;
    --color-success: #38a169;
    --color-warning: #ecc94b;
    --color-danger: #e53e3e;
    --color-info: #4299e1;
    --border-radius: 0.25rem;
    --transition-speed: 0.2s;
    --box-shadow: 0 4px 6px rgba(0, 0, 0, 0.3);
    --chart-height: 300px;
}

* {
    margin: 0;
    padding: 0;
    box-sizing: border-box;
}

body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif, 'Apple Color Emoji', 'Segoe UI Emoji', 'Segoe UI Symbol';
    background-color: var(--color-bg-primary);
    color: var(--color-text-primary);
    line-height: 1.6;
    font-size: 15px;
}

/* Accessibility */
a:focus, button:focus, input:focus, select:focus {
    outline: 2px solid var(--color-text-accent);
    outline-offset: 2px;
}

/* Main Layout */
#app {
    display: flex;
    flex-direction: column;
    min-height: 100vh;
}

header {
    background-color: var(--color-bg-secondary);
    padding: 0.75rem 1.25rem;
    box-shadow: var(--box-shadow);
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    position: sticky;
    top: 0;
    z-index: 10;
}

main {
    flex: 1;
    padding: 1.25rem;
    position: relative;
}

footer {
    background-color: var(--color-bg-secondary);
    padding: 0.75rem 1.25rem;
    text-align: center;
    font-size: 0.8rem;
    color: var(--color-text-secondary);
    border-top: 1px solid var(--color-bg-tertiary);
}

.footer-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    max-width: 1200px;
    margin: 0 auto;
    flex-wrap: wrap;
    gap: 1rem;
}

.footer-nav {
    display: flex;
    gap: 1rem;
}

.footer-nav a {
    color: var(--color-text-secondary);
    text-decoration: none;
    transition: color var(--transition-speed);
}

.footer-nav a:hover {
    color: var(--color-text-primary);
}

.footer-nav a.active {
    color: var(--color-text-accent);
    font-weight: 500;
}

/* Header Components */
.header-title h1 {
    font-size: 1.3rem;
    margin: 0;
    font-weight: 500;
}

/* Controls */
.controls {
    display: flex;
    gap: 0.75rem;
    align-items: center;
    flex-wrap: wrap;
}

.control-group {
    display: flex;
    align-items: center; /* Align label and control */
    gap: 0.3rem;
}

.button-group {
    display: flex;
    gap: 0.5rem;
    align-items: center;
}

label {
    font-size: 0.8rem;
    color: var(--color-text-secondary);
    white-space: nowrap;
}

select, input[type="text"], button {
    background-color: var(--color-bg-tertiary);
    color: var(--color-text-primary);
    border: 1px solid var(--color-bg-secondary);
    border-radius: var(--border-radius);
    padding: 0.4rem 0.6rem;
    font-size: 0.85rem;
    transition: all var(--transition-speed);
}

select:hover, input[type="text"]:hover, button:hover {
    border-color: var(--color-text-accent);
}

select:focus, input[type="text"]:focus {
    outline: none;
    border-color: var(--color-text-accent);
    box-shadow: 0 0 0 3px rgba(66, 153, 225, 0.5);
}

/* Auto-refresh toggle switch */
.auto-refresh {
    display: flex;
    align-items: center;
    gap: 0.5rem;
}

.switch {
    position: relative;
    display: inline-block;
    width: 34px; /* Smaller */
    height: 18px;
}

.switch input {
    opacity: 0;
    width: 0;
    height: 0;
}

.slider {
    position: absolute;
    cursor: pointer;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background-color: var(--color-bg-tertiary);
    transition: .4s;
}

.slider:before {
    position: absolute;
    content: "";
    height: 12px;
    width: 12px;
    left: 3px;
    bottom: 3px;
    background-color: var(--color-text-primary);
    transition: .4s;
}

input:checked + .slider {
    background-color: var(--color-success);
}

input:focus + .slider {
    box-shadow: 0 0 1px var(--color-success);
}

input:checked + .slider:before {
    transform: translateX(16px); /* Adjusted */
}

.slider.round {
    border-radius: 34px;
}

.slider.round:before {
    border-radius: 50%;
}

/* Buttons */
.button {
    cursor: pointer;
    display: inline-flex; /* Changed */
    align-items: center;
    justify-content: center; /* Center content */
    gap: 0.4rem;
    transition: all var(--transition-speed);
    white-space: nowrap;
    margin: 0;
    border: none; /* Added */
    line-height: 1.2; /* Added */
}

.button:hover {
    filter: brightness(1.15); /* Simple hover effect */
}

.button.primary {
    background-color: var(--color-bg-accent);
    color: white;
}
.button.primary:hover { background-color: #2b6cb0; }

.button.danger {
    background-color: var(--color-danger);
    color: white;
}
.button.danger:hover { background-color: #c53030; }

.button.warning {
    background-color: var(--color-warning);
    color: var(--color-bg-primary); /* Dark text */
}
.button.warning:hover { background-color: #d69e2e; }

.button.secondary { /* Added for manage/refresh */
    background-color: var(--color-bg-tertiary);
    color: var(--color-text-primary);
}
.button.secondary:hover { background-color: #718096; }


.button.small {
    padding: 0.25rem 0.5rem;
    font-size: 0.75rem;
}

.icon {
    font-size: 1rem;
    display: inline-block;
    vertical-align: middle; /* Align icon better */
    line-height: 1;
}

/* Status and Messages */
#status-indicator {
    background-color: var(--color-bg-secondary);
    border-radius: var(--border-radius);
    padding: 0.5rem 0.75rem;
    font-size: 0.8rem;
    margin-bottom: 1rem;
    display: flex;
    flex-wrap: wrap;
    gap: 1rem;
    color: var(--color-text-secondary);
}
#status-indicator span { margin-right: 1em; }

.message { /* Combined error/success message */
    color: white;
    padding: 0.75rem 1rem;
    border-radius: var(--border-radius);
    margin-bottom: 1rem;
    display: none; /* Hidden by default */
}
.message.error { background-color: var(--color-danger); }
.message.success { background-color: var(--color-success); }
.message.info { background-color: var(--color-info); }

/* Topology Container */
#topology-container {
    width: 100%;
    height: calc(100vh - 15rem); /* Adjust based on header/footer */
    min-height: 450px;
    background-color: var(--color-bg-secondary);
    border-radius: var(--border-radius);
    overflow: hidden;
    position: relative;
    box-shadow: var(--box-shadow);
}

#topology-graph {
    width: 100%;
    height: 100%;
    display: block;
    background-color: var(--color-bg-primary); /* Background for graph */
}

/* Tooltip */
.tooltip {
    position: absolute;
    display: none;
    background-color: rgba(45, 55, 72, 0.97); /* Darker, less transparent */
    color: var(--color-text-primary);
    border-radius: var(--border-radius);
    padding: 0.6rem 0.9rem;
    font-size: 0.8rem;
    max-width: 22rem;
    z-index: 1000;
    pointer-events: none;
    box-shadow: var(--box-shadow);
    border: 1px solid var(--color-bg-tertiary);
    line-height: 1.4;
}

.tooltip-content h3 {
    margin-bottom: 0.5rem;
    font-size: 0.9rem;
    border-bottom: 1px solid var(--color-bg-tertiary);
    padding-bottom: 0.3rem;
    color: var(--color-text-accent);
}

.tooltip-content p {
    margin-bottom: 0.3rem;
}
.tooltip-content strong { color: var(--color-text-secondary); margin-right: 0.3em; }

.tooltip-scroll {
    max-height: 100px; /* Slightly smaller */
    overflow-y: auto;
    margin-top: 0.5rem;
    padding-right: 5px; /* Space for scrollbar */
}

.tooltip-list {
    padding-left: 1rem;
    font-size: 0.75rem;
    list-style: none;
}
.tooltip-list li { margin-bottom: 0.15rem; }

/* Loading Indicator */
.loading {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    background-color: rgba(26, 32, 44, 0.85);
    color: var(--color-text-primary);
    padding: 1rem 2rem;
    border-radius: var(--border-radius);
    display: none;
    box-shadow: var(--box-shadow);
    z-index: 10;
    font-size: 0.9rem;
}

/* Legend */
.legend {
    position: absolute;
    bottom: 1.25rem; /* Position bottom left */
    left: 1.25rem;
    background-color: rgba(45, 55, 72, 0.9);
    padding: 0.75rem;
    border-radius: var(--border-radius);
    font-size: 0.75rem;
    z-index: 5;
    border: 1px solid var(--color-bg-tertiary);
    box-shadow: var(--box-shadow);
    max-width: 12rem;
    color: var(--color-text-secondary); /* Lighter text */
}

.legend h3, .legend h4 {
    margin-bottom: 0.5rem;
    font-size: 0.8rem;
    color: var(--color-text-primary);
    font-weight: 500;
}

.legend h4 {
    margin-top: 0.5rem;
    border-top: 1px solid var(--color-bg-tertiary);
    padding-top: 0.5rem;
}

.legend-item {
    display: flex;
    align-items: center;
    margin-bottom: 0.25rem;
}

.legend-symbol { /* Combined color/line */
    width: 0.75rem;
    height: 0.75rem;
    margin-right: 0.5rem;
    border: 1px solid rgba(255,255,255,0.2); /* Subtle border */
}
.legend-symbol.node { border-radius: 50%; }
.legend-symbol.link { height: 0.25rem; width: 1.5rem; border: none; }

/* Node Colors */
.legend-symbol.source { background-color: #1a7ad4; }
.legend-symbol.router { background-color: #718096; }
.legend-symbol.destination { background-color: #38a169; }
/* Link Loss Colors */
.legend-symbol.good { background-color: #38a169; }
.legend-symbol.warning { background-color: #ecc94b; }
.legend-symbol.medium { background-color: #ed8936; }
.legend-symbol.critical { background-color: #e53e3e; }

/* Modal for Agent Management */
.modal {
    position: fixed;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0, 0, 0, 0.7);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
    padding: 1rem;
}

.modal.hidden {
    display: none;
}

.modal-content {
    background-color: var(--color-bg-secondary);
    border-radius: var(--border-radius);
    width: 90%;
    max-width: 800px; /* Smaller max width */
    max-height: 90vh;
    display: flex; /* Use flex for layout */
    flex-direction: column;
    box-shadow: var(--box-shadow);
}

.modal-header {
    padding: 0.75rem 1.25rem;
    border-bottom: 1px solid var(--color-bg-tertiary);
    display: flex;
    justify-content: space-between;
    align-items: center;
    flex-shrink: 0; /* Prevent shrinking */
}
.modal-header h2 { font-size: 1.1rem; font-weight: 500; }

.modal-body {
    padding: 1.25rem;
    overflow-y: auto; /* Scroll only the body */
    flex-grow: 1; /* Allow body to grow */
}

.close-btn {
    background: none;
    border: none;
    font-size: 1.75rem;
    font-weight: bold;
    line-height: 1;
    color: var(--color-text-secondary);
    cursor: pointer;
    padding: 0 0.5rem; /* Add padding */
}

.close-btn:hover {
    color: var(--color-text-primary);
}

/* Agent Management Forms & Table */
.form-group {
    margin-bottom: 0.9rem;
}
.form-group label {
    display: block;
    margin-bottom: 0.3rem;
}
.form-group input[type="text"] {
    width: 100%;
}

.agent-list {
    margin-top: 1.5rem;
}
.agent-list h3 {
    margin-bottom: 0.75rem;
    font-size: 1rem;
    font-weight: 500;
}

.table-container {
    overflow-x: auto;
    max-height: 40vh; /* Limit table height */
    border: 1px solid var(--color-bg-tertiary);
    border-radius: var(--border-radius);
}

table {
    width: 100%;
    border-collapse: collapse;
}

th, td {
    padding: 0.6rem 0.8rem;
    text-align: left;
    border-bottom: 1px solid var(--color-bg-tertiary);
    white-space: nowrap;
    font-size: 0.85rem;
}
tr:last-child td { border-bottom: none; }

th {
    background-color: var(--color-bg-tertiary);
    color: var(--color-text-secondary);
    font-weight: 500;
    position: sticky;
    top: 0;
    z-index: 1;
}

tr:hover {
    background-color: var(--color-bg-primary);
}

.status-indicator { /* For table status */
    display: inline-block;
    padding: 0.15rem 0.5rem;
    border-radius: 1rem;
    font-size: 0.7rem;
    font-weight: 500;
    text-transform: uppercase;
}

.status-indicator.active { background-color: var(--color-success); color: white; }
.status-indicator.inactive { background-color: var(--color-bg-tertiary); color: var(--color-text-secondary); }
.status-indicator.warning { background-color: var(--color-warning); color: var(--color-bg-primary); }

td.actions {
    display: flex;
    gap: 0.25rem;
    flex-wrap: nowrap; /* Prevent wrapping */
}

/* Dashboard */
.dashboard-grid {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
    gap: 1.25rem;
    margin-bottom: 1rem;
}

.dashboard-card {
    background-color: var(--color-bg-secondary);
    border-radius: var(--border-radius);
    box-shadow: var(--box-shadow);
    overflow: hidden;
    display: flex;
    flex-direction: column;
}

.dashboard-card h2 {
    padding: 0.75rem 1.25rem;
    margin: 0;
    background-color: var(--color-bg-tertiary);
    font-size: 1.05rem;
    font-weight: 500;
    border-bottom: 1px solid var(--color-bg-primary);
}

.card-content {
    padding: 1rem 1.25rem;
    flex-grow: 1;
}
.card-content .no-data { color: var(--color-text-secondary); font-style: italic; }

.dashboard-chart {
    width: 100%;
    height: var(--chart-height);
    position: relative; /* Needed for Chart.js responsiveness */
}
.dashboard-chart canvas { max-height: var(--chart-height); } /* Ensure canvas respects height */


.summary-card {
    display: flex;
    flex-direction: column;
}

.summary-stat {
    display: flex;
    justify-content: space-between;
    padding: 0.4rem 0;
    border-bottom: 1px solid var(--color-bg-tertiary);
    font-size: 0.9rem;
}

.summary-stat:last-child { border-bottom: none; }

.stat-label { color: var(--color-text-secondary); }
.stat-value { font-weight: 500; }

/* Timeline for history */
.timeline {
    display: flex;
    flex-direction: column;
    gap: 0.75rem;
    max-height: 400px;
    overflow-y: auto;
    padding-right: 5px;
}

.timeline-item {
    padding: 0.8rem 1rem;
    background-color: var(--color-bg-tertiary);
    border-radius: var(--border-radius);
    position: relative;
    font-size: 0.8rem;
    border-left: 3px solid var(--color-bg-accent); /* Timeline marker */
}

.timeline-date {
    display: block;
    font-weight: 500;
    color: var(--color-text-secondary);
    margin-bottom: 0.4rem;
    font-size: 0.75rem;
}
.timeline-item p { margin-bottom: 0.3rem; line-height: 1.4; }
.timeline-item p small { color: var(--color-text-secondary); margin-right: 0.3em; }


/* About Page */
.about-container {
    max-width: 800px;
    margin: 0 auto;
    padding: 1rem;
}

.about-section {
    margin-bottom: 1.5rem;
    background-color: var(--color-bg-secondary);
    padding: 1.25rem;
    border-radius: var(--border-radius);
    box-shadow: var(--box-shadow);
}

.about-section h2 {
    margin-bottom: 1rem;
    border-bottom: 1px solid var(--color-bg-tertiary);
    padding-bottom: 0.5rem;
    font-size: 1.2rem;
    font-weight: 500;
}

.about-section p, .about-section ul, .about-section ol {
    margin-bottom: 0.8rem;
}

.about-section ul, .about-section ol {
    padding-left: 1.5rem; /* Use padding instead of margin */
}

.about-section li {
    margin-bottom: 0.4rem;
}

.info-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 0.9rem;
}

.info-table th, .info-table td {
    padding: 0.6rem;
    text-align: left;
    border: 1px solid var(--color-bg-tertiary);
}

.info-table th {
    background-color: var(--color-bg-tertiary);
    font-weight: 500;
}

/* Responsive adjustments */
@media (max-width: 768px) {
    header {
        flex-direction: column;
        align-items: flex-start; /* Align items left */
    }
    .controls { width: 100%; justify-content: space-between; }

    #topology-container {
        height: calc(100vh - 18rem); /* Adjust if header grows */
    }
    .legend { max-width: 90%; font-size: 0.7rem; }
    .modal-content { max-width: 95%; }
    .dashboard-grid { grid-template-columns: 1fr; } /* Stack cards */
}

@media (max-width: 480px) {
    body { font-size: 14px; }
    header { padding: 0.5rem 1rem; }
    main { padding: 1rem; }
    .header-title h1 { font-size: 1.1rem; }
    .controls { gap: 0.5rem; }
    select, input[type="text"], button { font-size: 0.8rem; padding: 0.3rem 0.5rem; }
    .legend { bottom: 1rem; left: 1rem; }
    .modal-header h2 { font-size: 1rem; }
    th, td { padding: 0.4rem 0.6rem; font-size: 0.8rem; }
}

/* Print styles */
@media print {
    body { background-color: #fff; color: #000; }
    header, footer, .controls, .legend, .modal, .button { display: none; }
    #topology-container { height: auto; box-shadow: none; border: 1px solid #ccc; }
    .dashboard-card { break-inside: avoid; border: 1px solid #ccc; box-shadow: none; }
}

/* Accessibility improvements */
@media (prefers-reduced-motion: reduce) {
    *, *::before, *::after {
        animation-duration: 0.01ms !important;
        animation-iteration-count: 1 !important;
        transition-duration: 0.01ms !important;
        scroll-behavior: auto !important;
    }
}
EOF

# 2. JS Utils
print_message "Creando web/static/js/utils.js..."
cat << 'EOF' > "$INSTALL_DIR/web/static/js/utils.js"
// Shared Utility Functions

/** Formats ISO date string to locale string */
function formatDateTime(isoString) {
    if (!isoString) return 'N/A';
    try {
        // Use more specific options for consistency
        const options = {
            year: 'numeric', month: 'short', day: 'numeric',
            hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false
        };
        return new Date(isoString).toLocaleString(undefined, options);
    } catch (e) { console.warn(`Date format error: ${isoString}`, e); return isoString; }
}

/** Escapes HTML special characters */
function escapeHtml(unsafe) {
    if (unsafe === null || unsafe === undefined) return '';
    // Added escaping for single quote
    return unsafe.toString()
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#039;");
}

/** Debounce function */
function debounce(func, delay) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => { clearTimeout(timeout); func.apply(this, args); };
        clearTimeout(timeout);
        timeout = setTimeout(later, delay);
    };
}

/** Shows/hides global loading indicator */
function showGlobalLoading(show, message = "Loading...") {
    const el = document.getElementById('loading');
    if (!el) return;
    el.textContent = message;
    el.style.display = show ? 'block' : 'none';
}

/** Shows a global message (error, success, etc.) */
function showGlobalMessage(message, timeout = 5000, type = 'error') {
    const el = document.getElementById('error-message'); // Assuming this is the correct ID
    if (!el) return;
    el.textContent = message;
    // Use class names for styling based on type
    el.className = `message ${type}`; // Base class + type class
    el.style.display = 'block';

    // Clear existing timer if present
    if (el.timerId) {
        clearTimeout(el.timerId);
    }

    // Auto-hide after timeout (if timeout > 0)
    if (timeout > 0) {
        el.timerId = setTimeout(() => {
            el.style.display = 'none';
            el.timerId = null; // Clear the stored timer ID
        }, timeout);
    } else {
         el.timerId = null; // Ensure no timer ID is stored for persistent messages
    }
}

/** Fetches JSON data from API endpoint */
async function fetchJSON(url) {
    let response;
    try {
        response = await fetch(url);
        if (!response.ok) {
             let errorMsg = `HTTP Error ${response.status}: ${response.statusText}`;
             try {
                  // Try to get more specific error from JSON response
                  const errData = await response.json();
                  errorMsg = errData?.error?.description || errData?.message || errorMsg;
             } catch (e) {
                 // Ignore if response is not JSON or fails to parse
             }
             throw new Error(errorMsg);
        }

        const result = await response.json();

        // Check for application-level errors within the JSON response
        if (result.status !== 'ok') {
             const appErrorMsg = result.error?.description || result.message || 'API returned non-ok status';
             throw new Error(appErrorMsg);
        }
        return result.data; // Return only the data part on success

    } catch (error) {
        // Log the detailed error and show a user-friendly message
        console.error(`API fetch error for ${url}:`, error);
        showGlobalMessage(`Failed to fetch data: ${error.message}`, 0, 'error'); // Show persistent error
        throw error; // Re-throw to allow caller to handle specific error cases if needed
    }
}

// Make functions globally available (alternative to modules for simplicity here)
window.formatDateTime = formatDateTime;
window.escapeHtml = escapeHtml;
window.debounce = debounce;
window.showGlobalLoading = showGlobalLoading;
window.showGlobalMessage = showGlobalMessage;
window.fetchJSON = fetchJSON;
EOF

# 3. JS Topology
print_message "Creando web/static/js/topology.js..."
cat << 'EOF' > "$INSTALL_DIR/web/static/js/topology.js"
// Topology Visualization using D3.js
// REQUIRES utils.js to be loaded first

document.addEventListener('DOMContentLoaded', function() {
    'use strict';
    // DOM References (Use descriptive names)
    const svgElement = document.getElementById('topology-graph');
    const tooltipElement = document.getElementById('tooltip');
    const groupSelect = document.getElementById('group-select');
    const agentSelect = document.getElementById('agent-select');
    const refreshBtn = document.getElementById('refresh-btn');
    const manageBtn = document.getElementById('manage-btn');
    const managementPanel = document.getElementById('management-panel');
    const closeModalBtn = document.getElementById('close-modal');
    const addAgentForm = document.getElementById('add-agent-form'); // Use form for submit event
    const agentsTableBody = document.querySelector('#agents-table tbody');
    const statusIndicator = document.getElementById('status-indicator');
    const filterForm = document.getElementById('filter-form'); // Use form for change event
    const autoRefreshToggle = document.getElementById('auto-refresh-toggle');
    const refreshIntervalSelect = document.getElementById('refresh-interval');

    // State (Centralized application state)
    const state = {
        topologyData: null,
        simulation: null,
        agentsData: [],
        groupsData: [],
        lastUpdate: null,
        refreshIntervalId: null,
        autoRefresh: false,
        autoRefreshIntervalMs: 60000, // Default 1 minute
        selectedGroup: 'all',
        selectedAgent: 'all',
        isInitialLoad: true // Flag for first load
    };

    // D3 Variables (Initialized later)
    let d3svg, zoomBehavior, linkGroup, nodeGroup, labelGroup;

    // --- Initialization ---
    function init() {
        console.log("Initializing Topology UI...");

        // Check for deep-link parameter from dashboard
        const focusAgent = sessionStorage.getItem('focusAgent');
        if (focusAgent) {
            state.selectedAgent = focusAgent;
            sessionStorage.removeItem('focusAgent'); // Consume the value
            console.log(`Deep link requested focus on agent: ${focusAgent}`);
        }

        loadConfig(); // Load saved settings first
        setupEventListeners();
        loadInitialData(); // Fetch initial data
        setupAutoRefresh(); // Start auto-refresh if enabled
        updateStatusIndicator(); // Show initial status
    }

    // --- Data Loading ---
    async function loadInitialData() {
        state.isInitialLoad = true;
        showGlobalLoading(true, "Loading initial data...");
        try {
            // Fetch agents and groups in parallel
            await Promise.all([loadAgents(), loadGroups()]);
            // Populate selects *after* data is loaded and *before* topology load
            populateGroupSelect();
            populateAgentSelect(); // This will apply state.selectedAgent if it came from deep link
            await loadTopologyData(false); // Load topology using current filters
        } catch (error) {
            // Error handled within individual load functions
            console.error('Initial data load failed overall.', error);
        } finally {
            showGlobalLoading(false);
            state.isInitialLoad = false;
        }
    }

    async function loadAgents() {
        try {
            state.agentsData = await fetchJSON('/api/agents'); // Fetch all agents
            console.log(`Loaded ${state.agentsData.length} agents`);
            // If management panel is open, refresh its table
            if (managementPanel && !managementPanel.classList.contains('hidden')) {
                populateAgentsTable();
            }
        } catch (error) {
            // fetchJSON handles showing the message
            state.agentsData = []; // Reset on failure
        }
    }

    async function loadGroups() {
        try {
            state.groupsData = await fetchJSON('/api/groups');
            console.log(`Loaded ${state.groupsData.length} groups`);
        } catch (error) {
            // fetchJSON handles showing the message
            state.groupsData = []; // Reset on failure
        }
    }

    async function loadTopologyData(showLoadingIndicator = true) {
        if (showLoadingIndicator) showGlobalLoading(true, "Fetching topology...");
        try {
            const params = new URLSearchParams();
            // Only add parameters if they are not 'all'
            if (state.selectedGroup !== 'all') params.append('group', state.selectedGroup);
            if (state.selectedAgent !== 'all') params.append('agent', state.selectedAgent);

            // Add cache buster only on manual refresh to bypass potential browser caching
            if(showLoadingIndicator) params.append('_t', Date.now());

            state.topologyData = await fetchJSON(`/api/topology?${params.toString()}`);
            state.lastUpdate = new Date().toISOString();
            console.log("Topology data loaded:", state.topologyData);
            renderTopologyGraph(state.topologyData); // Render the graph
            updateStatusIndicator(); // Update status info
        } catch (error) {
            // fetchJSON handles the error message display
            renderTopologyGraph(null); // Render empty state on error
        } finally {
            if (showLoadingIndicator) showGlobalLoading(false);
        }
    }

    // --- UI Population ---
    function populateGroupSelect() {
        if (!groupSelect) return;
        const currentVal = state.selectedGroup; // Store value before clearing
        groupSelect.innerHTML = '<option value="all">All Groups</option>'; // Reset options
        state.groupsData.sort().forEach(group => {
            const option = document.createElement('option');
            option.value = group;
            option.textContent = group;
            groupSelect.appendChild(option);
        });
        // Restore selected value if it still exists in the new list
        if (state.groupsData.includes(currentVal)) {
            groupSelect.value = currentVal;
        } else {
            groupSelect.value = 'all'; // Default to 'all' if previous selection is gone
            state.selectedGroup = 'all'; // Update state accordingly
        }
    }

    function populateAgentSelect() {
        if (!agentSelect) return;
        const currentGroup = state.selectedGroup;
        const currentAgentVal = state.selectedAgent; // Store value before clearing

        agentSelect.innerHTML = '<option value="all">All Agents</option>'; // Reset options

        // Filter agents based on the selected group
        const filteredAgents = (currentGroup === 'all')
            ? state.agentsData
            : state.agentsData.filter(agent => agent.group === currentGroup);

        // Sort agents alphabetically by name or address
        filteredAgents.sort((a, b) => (a.name || a.address).localeCompare(b.name || b.address));

        // Add options to the select
        filteredAgents.forEach(agent => {
            const option = document.createElement('option');
            option.value = agent.address;
            option.textContent = agent.name || agent.address; // Display name if available
            agentSelect.appendChild(option);
        });

        // Restore selected value if it exists in the *filtered* list
        if (filteredAgents.some(agent => agent.address === currentAgentVal)) {
            agentSelect.value = currentAgentVal;
        } else {
            agentSelect.value = 'all'; // Default to 'all' if previous selection is gone or not in group
            state.selectedAgent = 'all'; // Update state
        }
    }

    function populateAgentsTable() {
        if (!agentsTableBody) return;
        agentsTableBody.innerHTML = ''; // Clear existing rows

        if (state.agentsData.length === 0) {
            agentsTableBody.innerHTML = '<tr><td colspan="6">No agents configured. Add one above.</td></tr>';
            return;
        }

        // Sort agents before displaying
        const sortedAgents = [...state.agentsData].sort((a, b) => (a.name || a.address).localeCompare(b.name || b.address));

        sortedAgents.forEach(agent => {
            const row = agentsTableBody.insertRow();
            row.dataset.address = agent.address; // Store address for actions

            const statusClass = agent.enabled ? 'active' : 'inactive';
            const statusText = agent.enabled ? 'Enabled' : 'Disabled';
            const lastScan = formatDateTime(agent.last_scan); // Use utility

            // Use escapeHtml for all potentially user-provided content
            row.innerHTML = `
                <td>${escapeHtml(agent.address)}</td>
                <td>${escapeHtml(agent.name || agent.address)}</td>
                <td>${escapeHtml(agent.group || 'default')}</td>
                <td><span class="status-indicator ${statusClass}">${statusText}</span></td>
                <td>${lastScan}</td>
                <td class="actions">
                    <button class="button small scan-btn" title="Scan Now"><span class="icon">🔄</span></button>
                    <button class="button small toggle-btn ${agent.enabled ? 'warning' : 'primary'}" title="${agent.enabled ? 'Disable' : 'Enable'}">${agent.enabled ? 'Disable' : 'Enable'}</button>
                    <button class="button small danger remove-btn" title="Remove"><span class="icon">🗑️</span></button>
                </td>
            `;
        });
    }

    function updateStatusIndicator() {
        if (!statusIndicator) return;
        // Fetch real-time status from the backend
        fetch('/api/status')
            .then(response => {
                if (!response.ok) return Promise.reject(`Status fetch failed: ${response.status}`);
                return response.json();
            })
            .then(data => {
                if (data.status === 'ok') {
                    const info = data; // API returns full status object
                    const enabledAgentsCount = state.agentsData.filter(a => a.enabled).length;
                    statusIndicator.innerHTML = `
                        <span>Agents: ${enabledAgentsCount}/${state.agentsData.length}</span>
                        <span>Groups: ${state.groupsData.length}</span>
                        <span>Workers: ${info.worker_threads ?? 'N/A'}</span>
                        <span>Pending Jobs: ${info.pending_jobs ?? 'N/A'}</span>
                        ${state.lastUpdate ? `<span>Graph Update: ${formatDateTime(state.lastUpdate)}</span>` : ''}
                    `;
                } else {
                    throw new Error(data.message || 'Unknown status error');
                }
            })
            .catch(err => {
                console.error('Status update failed:', err);
                statusIndicator.textContent = "Status unavailable.";
            });
    }

    // --- D3 Graph Rendering ---
    function renderTopologyGraph(data) {
        if (!svgElement) return;

        // Initialize D3 selection if not already done
        if (!d3svg) { d3svg = d3.select(svgElement); }

        // Clear previous graph elements
        d3svg.selectAll("*").remove();

        // Handle empty data case
        if (!data || !data.nodes || !data.links || data.nodes.length <= 1) { // Need at least source + 1 node
            showEmptyMessage();
            return;
        }

        const { nodes, links } = data; // Destructure for clarity
        const width = svgElement.clientWidth || 800;
        const height = svgElement.clientHeight || 600;

        // --- D3 Scales ---
        const nodeRadiusScale = d3.scaleOrdinal(["source", "destination", "router"], [12, 10, 7]); // Slightly smaller radii
        const nodeColorScale = d3.scaleOrdinal(["source", "destination", "router"], ["#1a7ad4", "#38a169", "#718096"]);
        // Loss color scale: Green (0-0.1), Yellow (0.1-1), Orange (1-5), Red (>5)
        const lossColorScale = d3.scaleThreshold([0.1, 1, 5], ["#38a169", "#ecc94b", "#ed8936", "#e53e3e"]);
        // Link width scale based on number of destinations using this link (log scale for better visibility)
        const maxDestinations = d3.max(links, d => d.destinations?.length || 1) || 1;
        const linkWidthScale = d3.scaleLog().domain([1, Math.max(2, maxDestinations)]).range([1.5, 6]).clamp(true); // Thinner base, slightly less thick max

        // --- D3 Groups (Layers) ---
        // Create groups if they don't exist, otherwise select them
        linkGroup = d3svg.selectAppend("g").attr("class", "links");
        nodeGroup = d3svg.selectAppend("g").attr("class", "nodes");
        labelGroup = d3svg.selectAppend("g").attr("class", "labels");

        // --- D3 Simulation ---
        // Stop previous simulation if running
        if (state.simulation) { state.simulation.stop(); }

        state.simulation = d3.forceSimulation(nodes)
            .force("link", d3.forceLink(links).id(d => d.id).distance(80).strength(0.6)) // Shorter distance, slightly stronger link
            .force("charge", d3.forceManyBody().strength(-300)) // Less repulsion
            .force("center", d3.forceCenter(width / 2, height / 2))
            .force("collision", d3.forceCollide().radius(d => nodeRadiusScale(d.type) * 1.5 + 5)) // Collision based on radius
            .force("x", d3.forceX(width / 2).strength(0.02)) // Weaker centering forces
            .force("y", d3.forceY(height / 2).strength(0.02))
            .on("tick", ticked); // Update positions on each tick

        // --- D3 Elements ---
        // Links
        const link = linkGroup.selectAll("line")
            .data(links, d => d.id) // Use link ID for object constancy
            .join("line") // Enter, update, exit pattern
            .attr("stroke-width", d => linkWidthScale(d.destinations?.length || 1))
            .attr("stroke", d => lossColorScale(d.loss ?? 0)) // Default to 0 loss if null
            .style("opacity", 0.6)
            .on("mouseover", handleLinkMouseover)
            .on("mouseout", handleLinkMouseout);

        // Nodes
        const node = nodeGroup.selectAll("circle")
            .data(nodes, d => d.id) // Use node ID for object constancy
            .join("circle")
            .attr("r", d => nodeRadiusScale(d.type))
            .attr("fill", d => nodeColorScale(d.type))
            .style("stroke", "#fff") // White border
            .style("stroke-width", 1) // Thinner border
            .style("cursor", "pointer")
            .on("mouseover", handleNodeMouseover)
            .on("mouseout", handleNodeMouseout)
            .call(d3.drag() // Enable dragging
                .on("start", dragStarted)
                .on("drag", dragging)
                .on("end", dragEnded));

        // Labels
        const label = labelGroup.selectAll("text")
            .data(nodes, d => d.id)
            .join("text")
            .text(d => d.name || d.id) // Display name or ID
            .attr("font-size", 8) // Smaller labels
            .attr("text-anchor", "middle")
            .attr("dy", d => -(nodeRadiusScale(d.type) + 3)) // Position above node
            .style("fill", "#e2e8f0") // Light text color
            .style("paint-order", "stroke") // Ensure stroke is behind fill
            .style("stroke", "rgba(0,0,0,0.7)") // Subtle black outline for readability
            .style("stroke-width", "2px")
            .style("stroke-linecap", "butt")
            .style("stroke-linejoin", "miter")
            .style("pointer-events", "none") // Labels don't block interaction
            .style("user-select", "none");

        // --- D3 Tick Function ---
        function ticked() {
            link.attr("x1", d => d.source.x)
                .attr("y1", d => d.source.y)
                .attr("x2", d => d.target.x)
                .attr("y2", d => d.target.y);
            node.attr("cx", d => d.x)
                .attr("cy", d => d.y);
            label.attr("x", d => d.x)
                 .attr("y", d => d.y);
        }

        // --- Initial Node Positioning ---
        // Fix the source node to the left
        const sourceNode = nodes.find(n => n.type === 'source');
        if (sourceNode) {
            sourceNode.fx = 50; // Fixed X position near left edge
            sourceNode.fy = height / 2; // Fixed Y position in the middle
        }
        // Optionally fix destination nodes to the right if desired, but often better to let simulation run

        // --- D3 Interaction Handlers ---
        function handleLinkMouseover(event, d) {
            d3.select(this).transition().duration(150)
                .style("opacity", 1)
                .attr("stroke-width", d => linkWidthScale(d.destinations?.length || 1) * 1.5); // Embiggen link
            const destinationsList = (d.destinations || [])
                .map(dest => `<li>${escapeHtml(dest)}</li>`).join('');
            // Format tooltip content
            showTooltip(event, `
                <div class="tooltip-content">
                    <h3>Connection</h3>
                    <p><strong>From:</strong> ${escapeHtml(d.source.name || d.source.id)}</p>
                    <p><strong>To:</strong> ${escapeHtml(d.target.name || d.target.id)}</p>
                    <p><strong>Latency:</strong> ${d.latency != null ? d.latency.toFixed(2) + ' ms' : 'N/A'}</p>
                    <p><strong>Loss:</strong> ${d.loss != null ? d.loss.toFixed(2) + '%' : 'N/A'}</p>
                    <p><strong>Paths Via Link:</strong> ${d.destinations?.length || 0}</p>
                    ${destinationsList ? `<div class="tooltip-scroll"><strong>Destinations:</strong><ul class="tooltip-list">${destinationsList}</ul></div>` : ''}
                </div>`);
        }

        function handleLinkMouseout(event, d) {
            d3.select(this).transition().duration(150)
                .style("opacity", 0.6)
                .attr("stroke-width", d => linkWidthScale(d.destinations?.length || 1)); // Restore size
            hideTooltip();
        }

        // Build index for quick neighbor finding
        const linkedByIndex = {};
        links.forEach(d => {
            linkedByIndex[`${d.source.id},${d.target.id}`] = 1;
        });
        function isConnected(a, b) { // Check if nodes a and b are linked
            return linkedByIndex[`${a.id},${b.id}`] || linkedByIndex[`${b.id},${a.id}`] || a.id === b.id;
        }

        function handleNodeMouseover(event, d) {
            const currentRadius = nodeRadiusScale(d.type);
            d3.select(this).transition().duration(150).attr("r", currentRadius * 1.2); // Enlarge node

            // Fade out non-connected elements
            node.style("opacity", n => (isConnected(d, n)) ? 1 : 0.2);
            link.style("opacity", l => (l.source === d || l.target === d) ? 1 : 0.2);
            label.style("opacity", n => (isConnected(d, n)) ? 1 : 0.2);

            // Gather info for tooltip
            const connectedLinks = links.filter(l => l.source === d || l.target === d);
            const avgLatency = d3.mean(connectedLinks, l => l.latency);
            const maxLoss = d3.max(connectedLinks, l => l.loss);
            const destinations = new Set();
            connectedLinks.forEach(l => (l.destinations || []).forEach(dest => destinations.add(dest)));
            const destinationsList = Array.from(destinations)
                .map(dest => `<li>${escapeHtml(dest)}</li>`).join('');

            showTooltip(event, `
                <div class="tooltip-content">
                    <h3>${escapeHtml(d.name || d.id)}</h3>
                    <p><strong>IP:</strong> ${escapeHtml(d.ip || 'N/A')}</p>
                    <p><strong>Type:</strong> ${escapeHtml(d.type)}</p>
                    ${avgLatency != null ? `<p><strong>Avg Link Latency:</strong> ${avgLatency.toFixed(2)} ms</p>` : ''}
                    ${maxLoss != null ? `<p><strong>Max Link Loss:</strong> ${maxLoss.toFixed(2)}%</p>` : ''}
                    ${destinationsList ? `<div class="tooltip-scroll"><strong>Associated Destinations:</strong> (${destinations.size})<ul class="tooltip-list">${destinationsList}</ul></div>` : ''}
                    ${d.group ? `<p><strong>Group:</strong> ${escapeHtml(d.group)}</p>`: ''}
                </div>`);
        }

        function handleNodeMouseout(event, d) {
            d3.select(this).transition().duration(150).attr("r", nodeRadiusScale(d.type)); // Restore size
            // Restore opacity
            node.style("opacity", 1);
            link.style("opacity", 0.6);
            label.style("opacity", 1);
            hideTooltip();
        }

        // --- D3 Drag Handlers ---
        function dragStarted(event, d) {
            if (!event.active) state.simulation.alphaTarget(0.3).restart(); // Heat up simulation
            d.fx = d.x; // Fix node position
            d.fy = d.y;
        }
        function dragging(event, d) {
            d.fx = event.x; // Update fixed position
            d.fy = event.y;
        }
        function dragEnded(event, d) {
            if (!event.active) state.simulation.alphaTarget(0); // Cool down simulation
            // Unfix position unless it's the source node
            if (d.type !== "source") {
                d.fx = null;
                d.fy = null;
            }
        }

        // --- D3 Zoom Behavior ---
        // Initialize zoom only once
        if (!zoomBehavior) {
            zoomBehavior = d3.zoom()
                .scaleExtent([0.1, 4]) // Min/max zoom levels
                .on("zoom", (event) => {
                    // Apply transform to the main groups
                    linkGroup.attr("transform", event.transform);
                    nodeGroup.attr("transform", event.transform);
                    labelGroup.attr("transform", event.transform);
                });
            d3svg.call(zoomBehavior); // Apply zoom behavior to the SVG

            // --- Initial Zoom Fit (optional, run only once or on full refresh) ---
            // Calculate bounds of the rendered graph elements (needs a small delay after initial render)
            setTimeout(() => {
                 const bounds = d3svg.node().getBBox();
                 const fullWidth = bounds.width;
                 const fullHeight = bounds.height;
                 if (fullWidth === 0 || fullHeight === 0) return; // Avoid division by zero

                 const midX = bounds.x + fullWidth / 2;
                 const midY = bounds.y + fullHeight / 2;
                 const scale = Math.min(1, 0.9 / Math.max(fullWidth / width, fullHeight / height)); // 0.9 for padding
                 const translate = [width / 2 - scale * midX, height / 2 - scale * midY];

                 d3svg.transition().duration(750).call(
                     zoomBehavior.transform,
                     d3.zoomIdentity.translate(translate[0], translate[1]).scale(scale)
                 );
            }, 100); // Short delay for rendering
        }
    } // End renderTopologyGraph

    function showEmptyMessage() {
        if (!d3svg) d3svg = d3.select(svgElement);
        d3svg.selectAll("*").remove(); // Clear SVG
        const width = svgElement.clientWidth || 800;
        const height = svgElement.clientHeight || 600;
        // Display a message centered in the SVG
        d3svg.append("text")
            .attr("x", width / 2)
            .attr("y", height / 2 - 10)
            .attr("text-anchor", "middle")
            .style("fill", "#a0aec0") // Secondary text color
            .style("font-size", "16px")
            .text("No topology data available.");
        d3svg.append("text")
            .attr("x", width / 2)
            .attr("y", height / 2 + 20)
            .attr("text-anchor", "middle")
            .style("fill", "#718096") // Tertiary text color
            .style("font-size", "13px")
            .text("Add agents via 'Manage Agents' or check filters.");
    }

    function showTooltip(event, htmlContent) {
        if (!tooltipElement) return;
        tooltipElement.innerHTML = htmlContent;
        tooltipElement.style.display = 'block';
        // Position tooltip intelligently near the cursor
        const x = event.pageX;
        const y = event.pageY;
        const tooltipWidth = tooltipElement.offsetWidth;
        const tooltipHeight = tooltipElement.offsetHeight;
        const windowWidth = window.innerWidth;
        const windowHeight = window.innerHeight;

        let left = x + 15;
        let top = y - 10;

        // Adjust if tooltip goes off-screen right
        if (left + tooltipWidth > windowWidth - 10) {
            left = x - tooltipWidth - 15;
        }
        // Adjust if tooltip goes off-screen bottom
        if (top + tooltipHeight > windowHeight - 10) {
            top = y - tooltipHeight - 10;
        }
        // Adjust if tooltip goes off-screen left/top (less common)
        if (left < 10) left = 10;
        if (top < 10) top = 10;

        tooltipElement.style.left = `${left}px`;
        tooltipElement.style.top = `${top}px`;
    }

    function hideTooltip() {
        if (tooltipElement) tooltipElement.style.display = 'none';
    }

    // --- Agent Management API Calls ---
    async function handleAddAgentSubmit(event) {
        event.preventDefault(); // Prevent default form submission
        const ipInput = document.getElementById('new-agent-ip');
        const nameInput = document.getElementById('new-agent-name');
        const groupInput = document.getElementById('new-agent-group');

        const agentData = {
            address: ipInput.value.trim(),
            name: nameInput.value.trim() || null, // Send null if empty
            group: groupInput.value.trim() || 'default',
            enabled: true // Always enabled on add
        };

        if (!agentData.address) {
            showGlobalMessage('Agent address is required.', 5000, 'error');
            return;
        }

        showGlobalLoading(true, "Adding agent...");
        try {
            const response = await fetch('/api/agent', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(agentData)
            });
            const result = await response.json();

            if (response.ok && result.status === 'ok') {
                showGlobalMessage('Agent added successfully.', 3000, 'success');
                ipInput.value = ''; // Clear form
                nameInput.value = '';
                groupInput.value = 'default';
                // Refresh relevant data
                await Promise.all([loadAgents(), loadGroups()]);
                populateAgentsTable();
                populateGroupSelect();
                populateAgentSelect();
                await loadTopologyData(false); // Reload topology
            } else {
                throw new Error(result.error?.description || result.message || 'Failed to add agent');
            }
        } catch (err) {
            showGlobalMessage(`Error adding agent: ${err.message}`, 5000, 'error');
            console.error("Add agent error:", err);
        } finally {
            showGlobalLoading(false);
        }
    }

    async function handleAgentAction(event) {
        const button = event.target.closest('button'); // Find the clicked button
        if (!button) return; // Exit if click wasn't on a button

        const row = button.closest('tr');
        const address = row?.dataset.address;
        if (!address) return; // Exit if address not found

        // Prevent multiple clicks while processing
        button.disabled = true;
        showGlobalLoading(true, "Processing action...");

        try {
            if (button.classList.contains('scan-btn')) {
                await scanAgent(address);
            } else if (button.classList.contains('toggle-btn')) {
                const isCurrentlyEnabled = !button.classList.contains('primary'); // If not primary, it's warning (enabled)
                await toggleAgent(address, !isCurrentlyEnabled); // Toggle the state
            } else if (button.classList.contains('remove-btn')) {
                await removeAgent(address);
            }
        } catch (err) {
            // Errors are shown by the specific functions
            console.error(`Action failed for ${address}:`, err);
        } finally {
            showGlobalLoading(false);
            button.disabled = false; // Re-enable button
        }
    }

    async function scanAgent(address) {
        console.log(`Requesting scan for ${address}`);
        try {
            const response = await fetch(`/api/scan/${address}`, { method: 'POST' });
            const result = await response.json();
            if (response.ok && result.status === 'ok') {
                showGlobalMessage(`Scan requested for ${address}. Graph will update soon.`, 4000, 'success');
                // Optional: Trigger a slightly delayed topology refresh
                setTimeout(() => loadTopologyData(false), 5000);
            } else {
                throw new Error(result.error?.description || result.message || 'Scan request failed');
            }
        } catch (err) {
            showGlobalMessage(`Error scanning ${address}: ${err.message}`, 5000, 'error');
            console.error("Scan agent error:", err);
        }
    }

    async function toggleAgent(address, enable) {
        const action = enable ? 'Enabling' : 'Disabling';
        console.log(`${action} ${address}`);
        try {
            const response = await fetch(`/api/agent/${address}/status`, {
                method: 'PUT',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ enabled: enable })
            });
            const result = await response.json();
            if (response.ok && result.status === 'ok') {
                showGlobalMessage(`Agent ${address} ${enable ? 'enabled' : 'disabled'}.`, 3000, 'success');
                await loadAgents(); // Refresh agent list data
                populateAgentsTable(); // Update table display
                await loadTopologyData(false); // Refresh topology (agent might appear/disappear)
            } else {
                throw new Error(result.error?.description || result.message || 'Toggle failed');
            }
        } catch (err) {
            showGlobalMessage(`Error toggling ${address}: ${err.message}`, 5000, 'error');
            console.error("Toggle agent error:", err);
        }
    }

    async function removeAgent(address) {
        // Confirmation dialog
        if (!confirm(`Are you sure you want to permanently remove agent ${address}?`)) {
            return;
        }
        console.log(`Removing ${address}`);
        try {
            const response = await fetch(`/api/agent/${address}`, { method: 'DELETE' });
            const result = await response.json();
            if (response.ok && result.status === 'ok') {
                showGlobalMessage(`Agent ${address} removed.`, 3000, 'success');
                // Refresh all relevant data
                await Promise.all([loadAgents(), loadGroups()]);
                populateAgentsTable();
                populateGroupSelect();
                populateAgentSelect();
                await loadTopologyData(); // Full topology refresh needed
            } else {
                throw new Error(result.error?.description || result.message || 'Remove failed');
            }
        } catch (err) {
            showGlobalMessage(`Error removing ${address}: ${err.message}`, 5000, 'error');
            console.error("Remove agent error:", err);
        }
    }

    // --- Event Listeners Setup & Handlers ---
    function setupEventListeners() {
        refreshBtn?.addEventListener('click', () => loadTopologyData(true));
        manageBtn?.addEventListener('click', showManagementPanel);
        closeModalBtn?.addEventListener('click', hideManagementPanel);
        addAgentForm?.addEventListener('submit', handleAddAgentSubmit);
        agentsTableBody?.addEventListener('click', handleAgentAction); // Delegate actions
        filterForm?.addEventListener('change', handleFilterChange); // Delegate filter changes
        autoRefreshToggle?.addEventListener('change', handleAutoRefreshToggle);
        refreshIntervalSelect?.addEventListener('change', handleIntervalChange);

        // Close modal on Escape key
        document.addEventListener('keydown', (e) => {
            if (e.key === 'Escape' && managementPanel && !managementPanel.classList.contains('hidden')) {
                hideManagementPanel();
            }
        });
        // Refresh on F5 (prevent default page reload)
        document.addEventListener('keydown', (e) => {
             if (e.key === 'F5' && !e.ctrlKey && !e.shiftKey && !e.altKey) {
                 e.preventDefault();
                 loadTopologyData(true);
             }
        });
        // Responsive graph redraw on window resize (debounced)
        window.addEventListener('resize', debounce(() => {
            if (state.topologyData) {
                renderTopologyGraph(state.topologyData); // Redraw with existing data
            }
        }, 250));
    }

    function handleFilterChange(event) {
        const { id, value } = event.target; // Get ID and value of changed element
        if (id === 'group-select') {
            state.selectedGroup = value;
            // When group changes, repopulate agents and maybe reset agent filter
            populateAgentSelect();
        } else if (id === 'agent-select') {
            state.selectedAgent = value;
        }
        saveConfig(); // Save filter state
        loadTopologyData(); // Reload topology with new filters
    }

    function handleAutoRefreshToggle() {
        state.autoRefresh = autoRefreshToggle.checked;
        saveConfig();
        setupAutoRefresh(); // Start or stop the interval timer
    }

    function handleIntervalChange() {
        state.autoRefreshIntervalMs = parseInt(refreshIntervalSelect.value, 10) * 1000;
        saveConfig();
        setupAutoRefresh(); // Restart timer with new interval
    }

    function showManagementPanel() {
        if (!managementPanel) return;
        managementPanel.classList.remove('hidden');
        // Refresh agent list when panel is opened
        loadAgents().then(populateAgentsTable);
    }

    function hideManagementPanel() {
        if (managementPanel) managementPanel.classList.add('hidden');
    }

    // --- Config Persistence (LocalStorage) ---
    function loadConfig() {
        try {
            const savedConfig = localStorage.getItem('mtr_topology_config');
            if (savedConfig) {
                const config = JSON.parse(savedConfig);
                // Restore state from saved config, providing defaults
                state.autoRefresh = config.autoRefresh ?? false;
                state.autoRefreshIntervalMs = config.autoRefreshIntervalMs ?? 60000;
                state.selectedGroup = config.selectedGroup ?? 'all';
                state.selectedAgent = config.selectedAgent ?? 'all';

                // Apply loaded settings to UI elements
                if (autoRefreshToggle) autoRefreshToggle.checked = state.autoRefresh;
                if (refreshIntervalSelect) refreshIntervalSelect.value = (state.autoRefreshIntervalMs / 1000).toString();
                // Selects are populated later, their values will be set then based on state
                console.log("Config loaded:", state);
            }
        } catch (err) {
            console.error('Load config error:', err);
            // Use defaults if loading fails
        }
    }

    function saveConfig() {
        try {
            const configToSave = {
                autoRefresh: state.autoRefresh,
                autoRefreshIntervalMs: state.autoRefreshIntervalMs,
                selectedGroup: state.selectedGroup,
                selectedAgent: state.selectedAgent
            };
            localStorage.setItem('mtr_topology_config', JSON.stringify(configToSave));
            console.log("Config saved:", configToSave);
        } catch (err) {
            console.error('Save config error:', err);
            showGlobalMessage("Could not save settings.", 3000, 'error');
        }
    }

    // --- Auto Refresh Logic ---
    function setupAutoRefresh() {
        // Clear any existing interval
        if (state.refreshIntervalId) {
            clearInterval(state.refreshIntervalId);
            state.refreshIntervalId = null;
        }
        // Set new interval if auto-refresh is enabled
        if (state.autoRefresh) {
            state.refreshIntervalId = setInterval(() => {
                console.log("Auto-refreshing topology...");
                loadTopologyData(false); // Refresh without showing loading indicator
                updateStatusIndicator(); // Also refresh status periodically
            }, state.autoRefreshIntervalMs);

            // Update refresh button title/text
            if (refreshBtn) refreshBtn.title = `Auto-refreshing every ${state.autoRefreshIntervalMs / 1000}s. Click to refresh now.`;
        } else {
            if (refreshBtn) refreshBtn.title = 'Refresh manually'; // Reset title
        }
    }

    // --- D3 Utility for selectAppend ---
    // Helper to simplify appending elements if they don't exist
    // (https://observablehq.com/@d3/selectappend)
    d3.selection.prototype.selectAppend = function(name) {
      let node = this.select(name);
      if (!node.empty()) return node;
      const [tag, idOrClass] = name.split(/([.#])/); // Split by . or #
      node = this.append(tag);
      if (idOrClass === '#') node.attr('id', name.substring(tag.length + 1));
      if (idOrClass === '.') node.attr('class', name.substring(tag.length + 1));
      return node;
    };

    // --- Start the Application ---
    init();

});
EOF

# 4. JS Dashboard
print_message "Creando web/static/js/dashboard.js..."
cat << 'EOF' > "$INSTALL_DIR/web/static/js/dashboard.js"
// Dashboard Logic
// REQUIRES utils.js and Chart.js (loaded in HTML)

document.addEventListener('DOMContentLoaded', function() {
    'use strict';
    // --- DOM References ---
    const timeRangeSelect = document.getElementById('time-range');
    const groupSelect = document.getElementById('dashboard-group');
    const refreshBtn = document.getElementById('dashboard-refresh-btn');

    // Summary Card Elements
    const totalAgentsEl = document.getElementById('total-agents');
    const activeAgentsEl = document.getElementById('active-agents');
    const problemAgentsEl = document.getElementById('problem-agents');
    const avgLatencyEl = document.getElementById('avg-latency');
    const avgLossEl = document.getElementById('avg-loss');

    // Chart Containers
    const latencyChartContainer = document.getElementById('latency-chart');
    const lossChartContainer = document.getElementById('loss-chart');

    // Table & History Containers
    const agentsStatusTableBody = document.querySelector('#agents-status-table tbody');
    const topologyHistoryContainer = document.getElementById('topology-history');

    // --- State & Chart Instances ---
    let currentGroup = 'all';
    let currentTimeRange = '24h';
    let agentsData = []; // Store agent list for table enrichment
    let latencyChartInstance = null;
    let lossChartInstance = null;

    // --- Initialization ---
    function init() {
        console.log("Initializing Dashboard UI...");
        setupEventListeners();
        loadGroupsForSelect(); // Load groups first
        loadDashboardData();   // Then load all dashboard data
    }

    // --- Event Listeners ---
    function setupEventListeners() {
        timeRangeSelect?.addEventListener('change', handleFilterChange);
        groupSelect?.addEventListener('change', handleFilterChange);
        refreshBtn?.addEventListener('click', () => loadDashboardData(true)); // Pass true for manual refresh
    }

    function handleFilterChange() {
        currentTimeRange = timeRangeSelect?.value || '24h';
        currentGroup = groupSelect?.value || 'all';
        console.log(`Filters changed: Time=${currentTimeRange}, Group=${currentGroup}`);
        loadDashboardData(); // Reload data with new filters
    }

    // --- Data Loading ---
    async function loadGroupsForSelect() {
        if (!groupSelect) return;
        try {
            const groups = await fetchJSON('/api/groups');
            populateGroupSelect(groups || []);
        } catch (error) {
            // Error shown by fetchJSON
            console.error("Failed to load groups for dashboard select:", error);
        }
    }

    function populateGroupSelect(groups) {
        if (!groupSelect) return;
        const currentVal = groupSelect.value; // Preserve selection if possible
        groupSelect.innerHTML = '<option value="all">All Groups</option>'; // Reset
        groups.sort().forEach(g => {
            const option = document.createElement('option');
            option.value = g;
            option.textContent = g;
            groupSelect.appendChild(option);
        });
        // Restore selection
        if (groups.includes(currentVal)) {
            groupSelect.value = currentVal;
        } else {
            groupSelect.value = 'all'; // Default if previous selection invalid
            currentGroup = 'all'; // Update state
        }
    }

    async function loadDashboardData(isManualRefresh = false) {
        showGlobalLoading(true, "Loading dashboard data...");
        if(isManualRefresh){
            // Optional: Add cache buster for manual refresh
             console.log("Manual refresh triggered, adding cache buster.");
        }

        // Fetch all data concurrently
        const results = await Promise.allSettled([
            fetchJSON(`/api/dashboard/metrics?time_range=${currentTimeRange}&group=${currentGroup}`),
            fetchJSON(`/api/agents?group=${currentGroup}`), // Fetch agents for the selected group (or all)
            fetchJSON(`/api/dashboard/path_changes?time_range=${currentTimeRange}&group=${currentGroup}&limit=10`)
        ]);

        // Process results, updating UI components
        const [metricsResult, agentsResult, historyResult] = results;

        if (metricsResult.status === 'fulfilled') {
            const metricsData = metricsResult.value;
            updateSummaryCard(metricsData.summary || {});
            renderLatencyChart(metricsData.latency_timeseries || []);
            renderLossChart(metricsData.loss_timeseries || []);
        } else {
            console.error("Metrics fetch failed:", metricsResult.reason);
            // Optionally clear or show error state for summary/charts
            updateSummaryCard({}); renderLatencyChart([]); renderLossChart([]);
        }

        if (agentsResult.status === 'fulfilled') {
            agentsData = agentsResult.value || [];
            populateAgentStatusTable(agentsData); // Populate table with fetched agents
        } else {
            console.error("Agents fetch failed:", agentsResult.reason);
            populateAgentStatusTable([]); // Clear table on error
        }

        if (historyResult.status === 'fulfilled') {
            renderTopologyHistory(historyResult.value || []);
        } else {
            console.error("History fetch failed:", historyResult.reason);
            renderTopologyHistory([]); // Clear history on error
        }

        showGlobalLoading(false);
    }

    // --- UI Update Functions ---
    function updateSummaryCard(summary) {
        totalAgentsEl.textContent = summary.total_agents ?? '--';
        activeAgentsEl.textContent = summary.active_agents ?? '--';
        problemAgentsEl.textContent = summary.problem_agents ?? '--';
        avgLatencyEl.textContent = summary.avg_latency_overall != null ? `${summary.avg_latency_overall.toFixed(2)} ms` : '--';
        avgLossEl.textContent = summary.avg_loss_overall != null ? `${summary.avg_loss_overall.toFixed(2)} %` : '--';
    }

    function populateAgentStatusTable(agents) {
        if (!agentsStatusTableBody) return;
        agentsStatusTableBody.innerHTML = ''; // Clear table

        if (!agents || agents.length === 0) {
            agentsStatusTableBody.innerHTML = '<tr><td colspan="8">No agents found for this filter.</td></tr>';
            return;
        }

        // Sort agents before display
        agents.sort((a, b) => (a.name || a.address).localeCompare(b.name || b.address));

        agents.forEach(agent => {
            const row = agentsStatusTableBody.insertRow();
            // Determine status based on enabled and last scan success
            const statusClass = agent.enabled
                ? (agent.last_scan_success === false ? 'warning' : 'active') // Use === false explicitly
                : 'inactive';
            const statusText = agent.enabled
                ? (agent.last_scan_success === false ? 'Error' : 'OK')
                : 'Disabled';
            const lastScan = formatDateTime(agent.last_scan);

            // Placeholder for real-time metrics (would require another API or WebSocket)
            const currentLatency = 'N/A';
            const avgLatencyRange = 'N/A'; // Could fetch this per-agent, but expensive
            const packetLossRange = 'N/A'; // Could fetch this per-agent, but expensive

            row.innerHTML = `
                <td>${escapeHtml(agent.name || agent.address)}</td>
                <td>${escapeHtml(agent.group || 'default')}</td>
                <td><span class="status-indicator ${statusClass}">${statusText}</span></td>
                <td>${currentLatency}</td>
                <td>${avgLatencyRange}</td>
                <td>${packetLossRange}</td>
                <td>${lastScan}</td>
                <td class="actions">
                    <button class="button small secondary" onclick="navigateToAgent('${escapeHtml(agent.address)}')" title="View Topology">
                        <span class="icon">👁️</span> View
                    </button>
                </td>
            `;
        });
    }

    function renderTopologyHistory(history) {
        if (!topologyHistoryContainer) return;
        const timeline = topologyHistoryContainer.querySelector('.timeline');
        if (!timeline) return;
        timeline.innerHTML = ''; // Clear existing items

        if (!history || history.length === 0) {
            timeline.innerHTML = '<p>No recent path changes detected for this filter.</p>';
            return;
        }

        history.forEach(change => {
            const item = document.createElement('div');
            item.className = 'timeline-item';
            // Safely join paths, handle potential nulls/empties
            const oldPathStr = (change.old_path || []).join(' → ') || 'N/A';
            const newPathStr = (change.new_path || []).join(' → ') || 'N/A';

            item.innerHTML = `
                <span class="timeline-date">${formatDateTime(change.change_time)}</span>
                <p><strong>Path change: ${escapeHtml(change.source)} → ${escapeHtml(change.destination)}</strong></p>
                <p><small>Old:</small> ${escapeHtml(oldPathStr)}</p>
                <p><small>New:</small> ${escapeHtml(newPathStr)}</p>
                ${change.previous_duration_str ? `<p><small>Prev Duration:</small> ${escapeHtml(change.previous_duration_str)}</p>` : ''}
            `;
            timeline.appendChild(item);
        });
    }

    // --- Chart Rendering ---
    // Ensure Chart.js and adapter are loaded via dashboard.html

    function renderLatencyChart(data) {
        if (!latencyChartContainer) return;
        if (latencyChartInstance) {
            latencyChartInstance.destroy(); // Clean up previous chart
        }
        latencyChartContainer.innerHTML = ''; // Clear any placeholder text
        if (!data || data.length === 0) {
            latencyChartContainer.innerHTML = '<p class="no-data">No latency data available for this period.</p>';
            return;
        }

        const canvas = document.createElement('canvas');
        latencyChartContainer.appendChild(canvas);
        const ctx = canvas.getContext('2d');

        const labels = data.map(d => new Date(d.time));
        const p50Data = data.map(d => d.p50);
        const p95Data = data.map(d => d.p95);

        latencyChartInstance = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [
                    {
                        label: 'P95 Latency (ms)', // Often max in simple cases
                        data: p95Data,
                        borderColor: 'rgba(237, 137, 54, 0.8)', // Orange
                        backgroundColor: 'rgba(237, 137, 54, 0.1)',
                        borderWidth: 1.5,
                        tension: 0.1,
                        fill: false,
                        spanGaps: true, // Connect lines over gaps
                        pointRadius: 0, // Hide points for cleaner look
                        pointHoverRadius: 4,
                    },
                    {
                        label: 'P50 Latency (ms)', // Often avg in simple cases
                        data: p50Data,
                        borderColor: 'rgba(66, 153, 225, 0.8)', // Blue
                        backgroundColor: 'rgba(66, 153, 225, 0.1)',
                        borderWidth: 1.5,
                        tension: 0.1,
                        fill: false, // Can set to '+1' to fill to P95
                        spanGaps: true,
                        pointRadius: 0,
                        pointHoverRadius: 4,
                    }
                ]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: {
                    x: {
                        type: 'time',
                        time: {
                            // Automatically choose appropriate unit
                            tooltipFormat: 'MMM d, yyyy, HH:mm:ss' // Tooltip format
                        },
                        title: { display: true, text: 'Time' }
                    },
                    y: {
                        beginAtZero: true,
                        title: { display: true, text: 'Latency (ms)' }
                    }
                },
                plugins: {
                    tooltip: { bodyFont: { size: 10 } },
                    legend: { labels: { font: { size: 10 } } }
                }
            }
        });
    }

    function renderLossChart(data) {
        if (!lossChartContainer) return;
        if (lossChartInstance) {
            lossChartInstance.destroy();
        }
        lossChartContainer.innerHTML = '';
        if (!data || data.length === 0) {
            lossChartContainer.innerHTML = '<p class="no-data">No packet loss data available for this period.</p>';
            return;
        }

        const canvas = document.createElement('canvas');
        lossChartContainer.appendChild(canvas);
        const ctx = canvas.getContext('2d');

        const labels = data.map(d => new Date(d.time));
        const lossData = data.map(d => d.avg_loss);

        lossChartInstance = new Chart(ctx, {
            type: 'line',
            data: {
                labels: labels,
                datasets: [{
                    label: 'Avg Packet Loss (%)',
                    data: lossData,
                    borderColor: 'rgba(229, 62, 62, 0.8)', // Red
                    backgroundColor: 'rgba(229, 62, 62, 0.1)',
                    borderWidth: 1.5,
                    tension: 0.1,
                    fill: true, // Fill area under line
                    spanGaps: true,
                    pointRadius: 0,
                    pointHoverRadius: 4,
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                interaction: { mode: 'index', intersect: false },
                scales: {
                    x: {
                        type: 'time',
                        time: { tooltipFormat: 'MMM d, yyyy, HH:mm:ss' },
                        title: { display: true, text: 'Time' }
                    },
                    y: {
                        beginAtZero: true,
                        suggestedMax: 10, // Start with a lower max, auto-scales if needed
                        max: 100, // Absolute max is 100%
                        title: { display: true, text: 'Packet Loss (%)' },
                        ticks: { callback: function(value) { return value + '%' } } // Add % sign
                    }
                },
                 plugins: {
                    tooltip: { bodyFont: { size: 10 } },
                    legend: { labels: { font: { size: 10 } } }
                }
            }
        });
    }

    // --- Global Function for Navigation ---
    // Allows table buttons to trigger navigation to the topology view
    window.navigateToAgent = function(agentAddress) {
        // Use sessionStorage to pass the agent to focus on
        sessionStorage.setItem('focusAgent', agentAddress);
        // Redirect to the main topology page
        window.location.href = '/';
    };

    // --- Start Dashboard ---
    init();
});
EOF

# 5. HTML Index
print_message "Creando web/templates/index.html..."
cat << 'EOF' > "$INSTALL_DIR/web/templates/index.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="MTR Topology Visualizer - Network topology visualization tool">
    <title>MTR Topology Visualizer</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    <!-- <link rel="icon" href="{{ url_for('static', filename='img/favicon.ico') }}" type="image/x-icon"> -->
</head>
<body>
    <div id="app">
        <header>
            <div class="header-title">
                <h1>MTR Topology Visualizer</h1>
            </div>

            <div class="controls">
                <form id="filter-form" class="control-group"> <!-- Wrap filters in form -->
                    <label for="group-select">Group:</label>
                    <select id="group-select" name="group">
                        <option value="all">All Groups</option>
                        <!-- Populated by JS -->
                    </select>

                    <label for="agent-select">Agent:</label>
                    <select id="agent-select" name="agent">
                        <option value="all">All Agents</option>
                        <!-- Populated by JS -->
                    </select>
                </form>

                <div class="button-group">
                     <div class="control-group auto-refresh">
                        <label for="auto-refresh-toggle" title="Toggle automatic data refresh">Auto:</label>
                        <label class="switch">
                            <input type="checkbox" id="auto-refresh-toggle">
                            <span class="slider round"></span>
                        </label>
                        <label for="refresh-interval" class="sr-only">Refresh Interval</label> <!-- Screen reader only -->
                        <select id="refresh-interval" title="Set refresh interval">
                            <option value="30">30s</option>
                            <option value="60" selected>1m</option>
                            <option value="180">3m</option>
                            <option value="300">5m</option>
                            <option value="600">10m</option>
                        </select>
                    </div>
                    <button id="refresh-btn" class="button secondary" title="Refresh data now (F5)">
                        <span class="icon">⟳</span> Refresh
                    </button>
                    <button id="manage-btn" class="button secondary" title="Add, remove, or configure agents">
                        <span class="icon">⚙️</span> Manage Agents
                    </button>
                </div>
            </div>
        </header>

        <main>
            <div id="error-message" class="message" style="display: none;"></div> <!-- For global messages -->
            <div id="status-indicator">Loading status...</div>

            <div id="topology-container">
                <svg id="topology-graph"></svg>
                <div id="tooltip" class="tooltip"></div>
                <div id="loading" class="loading" style="display: none;">Loading data...</div>

                <div class="legend">
                    <h3>Legend</h3>
                    <h4>Nodes</h4>
                    <div class="legend-item"><span class="legend-symbol node source"></span> Source</div>
                    <div class="legend-item"><span class="legend-symbol node router"></span> Router/Hop</div>
                    <div class="legend-item"><span class="legend-symbol node destination"></span> Destination</div>
                    <h4>Link Loss (%)</h4>
                    <div class="legend-item"><span class="legend-symbol link good"></span> 0 - 0.1</div>
                    <div class="legend-item"><span class="legend-symbol link warning"></span> 0.1 - 1</div>
                    <div class="legend-item"><span class="legend-symbol link medium"></span> 1 - 5</div>
                    <div class="legend-item"><span class="legend-symbol link critical"></span> &gt; 5</div>
                </div>
            </div>

            <!-- Agent Management Panel (Modal) -->
            <div id="management-panel" class="modal hidden">
                <div class="modal-content">
                    <div class="modal-header">
                        <h2>Agent Management</h2>
                        <button id="close-modal" class="close-btn" title="Close">&times;</button>
                    </div>
                    <div class="modal-body">
                        <form id="add-agent-form">
                             <h3>Add New Agent</h3>
                             <div class="form-group">
                                <label for="new-agent-ip">IP Address or Hostname:</label>
                                <input type="text" id="new-agent-ip" placeholder="e.g., 192.168.1.1 or router.example.com" required>
                            </div>
                            <div class="form-group">
                                <label for="new-agent-name">Display Name (optional):</label>
                                <input type="text" id="new-agent-name" placeholder="e.g., Core Router NYC">
                            </div>
                            <div class="form-group">
                                <label for="new-agent-group">Group:</label>
                                <input type="text" id="new-agent-group" placeholder="e.g., Datacenter-A" value="default">
                            </div>
                            <button type="submit" class="button primary">Add Agent</button>
                        </form>

                        <div class="agent-list">
                            <h3>Configured Agents</h3>
                            <div class="table-container">
                                <table id="agents-table">
                                    <thead>
                                        <tr>
                                            <th>Address</th>
                                            <th>Name</th>
                                            <th>Group</th>
                                            <th>Status</th>
                                            <th>Last Scan</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        <!-- Populated by JS -->
                                        <tr><td colspan="6">Loading agents...</td></tr>
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    </div> <!-- /modal-body -->
                </div> <!-- /modal-content -->
            </div> <!-- /management-panel -->
        </main>

        <footer>
            <div class="footer-content">
                <p>MTR Topology Visualizer</p> <!-- Version maybe added dynamically -->
                <nav class="footer-nav">
                    <a href="/" class="active">Topology</a>
                    <a href="/dashboard">Dashboard</a>
                    <a href="/about">About</a>
                </nav>
            </div>
        </footer>
    </div> <!-- /app -->

    <!-- Import D3.js -->
    <script src="{{ url_for('static', filename='js/d3.v7.min.js') }}"></script>
    <!-- Import Utilities -->
    <script src="{{ url_for('static', filename='js/utils.js') }}"></script>
    <!-- Import Page Specific Logic -->
    <script src="{{ url_for('static', filename='js/topology.js') }}"></script>
</body>
</html>
EOF

# 6. HTML Dashboard
print_message "Creando web/templates/dashboard.html..."
cat << 'EOF' > "$INSTALL_DIR/web/templates/dashboard.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="MTR Topology Visualizer - Dashboard">
    <title>Dashboard - MTR Topology Visualizer</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    <!-- <link rel="icon" href="{{ url_for('static', filename='img/favicon.ico') }}" type="image/x-icon"> -->
    <!-- Chart.js and Date Adapter are required for charts -->
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1/dist/chart.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns/dist/chartjs-adapter-date-fns.bundle.min.js"></script>
</head>
<body>
    <div id="app">
        <header>
            <div class="header-title">
                <h1>MTR Dashboard</h1>
            </div>

            <div class="controls">
                 <div class="control-group"> <!-- Moved filters together -->
                    <label for="time-range">Time Range:</label>
                    <select id="time-range">
                        <option value="1h">Last Hour</option>
                        <option value="6h">Last 6 Hours</option>
                        <option value="24h" selected>Last 24 Hours</option>
                        <option value="7d">Last 7 Days</option>
                        <option value="30d">Last 30 Days</option>
                    </select>
                 </div>
                 <div class="control-group">
                    <label for="dashboard-group">Group:</label>
                    <select id="dashboard-group">
                        <option value="all">All Groups</option>
                        <!-- Populated by JS -->
                    </select>
                 </div>
                 <div class="button-group"> <!-- Refresh button separate -->
                    <button id="dashboard-refresh-btn" class="button secondary" title="Refresh dashboard data">
                        <span class="icon">⟳</span> Refresh
                    </button>
                 </div>
            </div>
        </header>

        <main>
            <div id="error-message" class="message" style="display: none;"></div>
            <div id="loading" class="loading" style="display: none;">Loading data...</div> <!-- Global Loading -->

            <div class="dashboard-grid">
                <div class="dashboard-card summary-card">
                    <h2>Network Summary</h2>
                    <div id="summary-content" class="card-content">
                        <div class="summary-stat">
                            <span class="stat-label">Total Agents:</span>
                            <span class="stat-value" id="total-agents">--</span>
                        </div>
                        <div class="summary-stat">
                            <span class="stat-label">Active Agents:</span>
                            <span class="stat-value" id="active-agents">--</span>
                        </div>
                        <div class="summary-stat">
                            <span class="stat-label">Agents with Issues:</span>
                            <span class="stat-value" id="problem-agents">--</span>
                        </div>
                        <div class="summary-stat">
                            <span class="stat-label">Avg Latency (Range):</span>
                            <span class="stat-value" id="avg-latency">--</span>
                        </div>
                        <div class="summary-stat">
                            <span class="stat-label">Avg Packet Loss (Range):</span>
                            <span class="stat-value" id="avg-loss">--</span>
                        </div>
                    </div>
                </div>

                <div class="dashboard-card">
                    <h2>Latency Overview (P50/P95)</h2>
                    <div class="card-content">
                        <div id="latency-chart" class="dashboard-chart">
                            <canvas></canvas> <!-- Canvas for Chart.js -->
                        </div>
                    </div>
                </div>

                <div class="dashboard-card">
                    <h2>Packet Loss Overview (Avg)</h2>
                    <div class="card-content">
                        <div id="loss-chart" class="dashboard-chart">
                            <canvas></canvas> <!-- Canvas for Chart.js -->
                        </div>
                    </div>
                </div>

                <div class="dashboard-card full-width">
                    <h2>Agent Status</h2>
                    <div class="card-content">
                        <div class="table-container">
                            <table id="agents-status-table" class="status-table">
                                <thead>
                                    <tr>
                                        <th>Agent</th>
                                        <th>Group</th>
                                        <th>Status</th>
                                        <th>Current Latency</th> <!-- Future metric -->
                                        <th>Avg Latency (Range)</th> <!-- Future metric -->
                                        <th>Packet Loss (Range)</th> <!-- Future metric -->
                                        <th>Last Scan</th>
                                        <th>Actions</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <tr><td colspan="8">Loading agent status...</td></tr>
                                    <!-- Populated by JS -->
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>

                <div class="dashboard-card full-width">
                    <h2>Recent Path Changes</h2>
                    <div class="card-content">
                        <div id="topology-history">
                            <div class="timeline">
                                <p>Loading path changes...</p>
                                <!-- Populated by JS -->
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </main>

        <footer>
            <div class="footer-content">
                <p>MTR Topology Visualizer</p>
                <nav class="footer-nav">
                    <a href="/">Topology</a>
                    <a href="/dashboard" class="active">Dashboard</a>
                    <a href="/about">About</a>
                </nav>
            </div>
        </footer>
    </div> <!-- /app -->

    <!-- Import Utilities -->
    <script src="{{ url_for('static', filename='js/utils.js') }}"></script>
    <!-- Import Dashboard Logic -->
    <script src="{{ url_for('static', filename='js/dashboard.js') }}"></script>
</body>
</html>
EOF

# 7. HTML About
print_message "Creando web/templates/about.html..."
cat << 'EOF' > "$INSTALL_DIR/web/templates/about.html"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="description" content="MTR Topology Visualizer - About">
    <title>About - MTR Topology Visualizer</title>
    <link rel="stylesheet" href="{{ url_for('static', filename='css/style.css') }}">
    <!-- <link rel="icon" href="{{ url_for('static', filename='img/favicon.ico') }}" type="image/x-icon"> -->
</head>
<body>
    <div id="app">
        <header>
            <div class="header-title">
                <h1>About MTR Topology Visualizer</h1>
            </div>
             <div class="button-group"> <!-- Added Back Button -->
                 <a href="/" class="button secondary"><span class="icon">←</span> Back to Topology</a>
             </div>
        </header>

        <main>
            <div class="about-container">
                <section class="about-section">
                    <h2>Overview</h2>
                    <p>
                        MTR Topology Visualizer provides an interactive way to visualize network paths and performance characteristics
                        to multiple destinations. It leverages MTR-like probing (ICMP traceroute combined with latency/loss statistics)
                        to map network hops and identify potential issues.
                    </p>
                    <p>
                        Data is collected periodically, stored in InfluxDB v1.x, and presented through a web interface featuring
                        an interactive graph (using D3.js) and a performance dashboard (using Chart.js).
                    </p>
                </section>

                <section class="about-section">
                    <h2>Features</h2>
                    <ul>
                        <li>Continuous network path monitoring to configured agents.</li>
                        <li>Interactive topology graph showing nodes (source, routers, destinations) and links.</li>
                        <li>Link coloring based on packet loss percentage.</li>
                        <li>Link thickness potentially indicating path usage (number of destinations).</li>
                        <li>Agent management (add/remove/enable/disable) via web UI, stored in `agents.json`.</li>
                        <li>Agent grouping for organizational purposes and filtering.</li>
                        <li>Dashboard displaying overall network health, latency/loss trends, and recent path changes.</li>
                        <li>REST API for accessing topology, agent, and metrics data.</li>
                        <li>Systemd service for background operation, running as a dedicated non-root user (`mtrtopology`).</li>
                    </ul>
                </section>

                 <section class="about-section">
                    <h2>How It Works</h2>
                    <ol>
                        <li>The <strong>Backend Service</strong> (Python/Flask) runs continuously.</li>
                        <li>A <strong>Scheduler</strong> triggers periodic scans for all <strong>enabled agents</strong> listed in `agents.json`.</li>
                        <li>The <strong>MTR Runner</strong> uses ICMP probes (like traceroute) to discover hops towards each agent.</li>
                        <li>For each hop, multiple probes measure <strong>latency</strong> and <strong>packet loss</strong>.</li>
                        <li>Results are formatted and stored in the configured <strong>InfluxDB v1.x</strong> database.</li>
                        <li>The <strong>Web UI</strong> (HTML/CSS/JS) queries the backend's <strong>API</strong>.</li>
                        <li>The API retrieves data from InfluxDB (for topology/metrics) and `agents.json` (for agent list).</li>
                        <li><strong>D3.js</strong> renders the interactive topology graph based on API data.</li>
                        <li><strong>Chart.js</strong> renders the performance graphs on the dashboard.</li>
                    </ol>
                </section>

                <section class="about-section">
                    <h2>System Components & Requirements</h2>
                    <table class="info-table">
                        <thead>
                            <tr><th>Component</th><th>Details</th></tr>
                        </thead>
                        <tbody>
                            <tr><td>Operating System</td><td>Linux (Debian/Ubuntu recommended)</td></tr>
                            <tr><td>Backend</td><td>Python 3.7+, Flask, InfluxDB Client</td></tr>
                            <tr><td>Frontend</td><td>HTML5, CSS3, JavaScript, D3.js v7, Chart.js v3</td></tr>
                            <tr><td>Database</td><td>InfluxDB v1.x</td></tr>
                            <tr><td>Agent Config</td><td>JSON file (`agents.json`)</td></tr>
                            <tr><td>Network Probing</td><td>ICMP (requires `CAP_NET_RAW` capability)</td></tr>
                             <tr><td>Service Management</td><td>Systemd (runs as `mtrtopology` user)</td></tr>
                        </tbody>
                    </table>
                     <p style="margin-top: 1em; font-size: 0.85em; color: var(--color-text-secondary);">
                        Note: Root privileges are needed only during installation via `install.sh` to set up the user, directories, and capabilities. The service itself runs without root.
                    </p>
                </section>

                 <section class="about-section">
                    <h2>Security Considerations</h2>
                    <p>
                        This application does <strong>not</strong> include built-in authentication or authorization for its web interface or API.
                        It is crucial to secure access in a production environment. Recommendations include:
                    </p>
                    <ul>
                        <li>Running the service behind a reverse proxy (like Nginx or Apache) that handles authentication (e.g., Basic Auth, LDAP, OAuth).</li>
                        <li>Using firewall rules (e.g., `ufw`, `iptables`) to restrict access to the web port (default 5000) to trusted IP ranges or networks.</li>
                        <li>Deploying within a VPN or private network.</li>
                        <li>Ensuring the InfluxDB instance is also properly secured.</li>
                    </ul>
                    <p>
                        The backend service runs as a non-root user (`mtrtopology`) with only the necessary `CAP_NET_RAW` capability for sending ICMP probes, minimizing potential system impact.
                    </p>
                </section>
            </div>
        </main>

        <footer>
            <div class="footer-content">
                <p>MTR Topology Visualizer</p>
                <nav class="footer-nav">
                    <a href="/">Topology</a>
                    <a href="/dashboard">Dashboard</a>
                    <a href="/about" class="active">About</a>
                </nav>
            </div>
        </footer>
    </div> <!-- /app -->
    <!-- No specific JS needed for about page, but utils could be added if dynamic elements are introduced -->
    <!-- <script src="{{ url_for('static', filename='js/utils.js') }}"></script> -->
</body>
</html>
EOF

# --- Descargar D3.js ---
D3_JS_PATH="$INSTALL_DIR/web/static/js/d3.v7.min.js"
if [ ! -f "$D3_JS_PATH" ]; then
    print_message "Descargando D3.js (v7)..."
    if command -v wget &> /dev/null; then
        wget -q https://d3js.org/d3.v7.min.js -O "$D3_JS_PATH" || print_warning "wget: Fallo al descargar D3.js."
    elif command -v curl &> /dev/null; then
        curl -sSL https://d3js.org/d3.v7.min.js -o "$D3_JS_PATH" || print_warning "curl: Fallo al descargar D3.js."
    else
        print_warning "Ni wget ni curl encontrados. No se pudo descargar D3.js. La visualización fallará."
    fi
else
    print_message "D3.js ($D3_JS_PATH) ya existe."
fi


# --- Establecer Permisos ---
print_message "Estableciendo permisos para el frontend..."
if [[ "$INSTALL_DIR" == /opt/* ]]; then
    # Si es /opt, asumir que el usuario/grupo del backend existe o debe existir
    if id "$APP_USER" &>/dev/null && getent group "$APP_GROUP" &>/dev/null; then
        print_message "Estableciendo propietario $APP_USER:$APP_GROUP para $INSTALL_DIR/web"
        chown -R "$APP_USER":"$APP_GROUP" "$INSTALL_DIR/web" || { print_error "Fallo al cambiar propietario."; exit 1; }
        # Permisos: User/Group: rwx para directorios, rw para archivos
        find "$INSTALL_DIR/web" -type d -exec chmod 770 {} \;
        find "$INSTALL_DIR/web" -type f -exec chmod 660 {} \;
    else
        print_error "Usuario '$APP_USER' o grupo '$APP_GROUP' no encontrado."
        print_error "Si instalas en /opt, ejecuta primero el script de despliegue del backend."
        exit 1
    fi
else
    # Si no es /opt, establecer propietario al usuario que ejecuta el script
    CURRENT_USER=$(whoami)
    CURRENT_GROUP=$(id -g -n "$CURRENT_USER")
    print_message "Estableciendo propietario $CURRENT_USER:$CURRENT_GROUP para $INSTALL_DIR/web"
    chown -R "$CURRENT_USER":"$CURRENT_GROUP" "$INSTALL_DIR/web" || print_warning "Fallo al cambiar propietario."
    # Permisos: User: rwx para directorios, rw para archivos
    chmod -R u+rwX "$INSTALL_DIR/web"
fi

print_message "==============================================="
print_message "Despliegue de archivos del Frontend completado en $INSTALL_DIR"
print_message "Ahora puedes desplegar el backend si aún no lo has hecho."
echo -e "${NC}" # Reset color

exit 0
