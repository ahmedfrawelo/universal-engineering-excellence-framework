import fs from 'node:fs';
import path from 'node:path';

const htmlPath = path.resolve(process.argv[2] || '');
const searchQuery = process.argv[3] || 'selectDesignProductionRoute';
if (!fs.existsSync(htmlPath)) throw new Error(`Viewer HTML does not exist: ${htmlPath}`);
const html = fs.readFileSync(htmlPath, 'utf8');
const inlineScripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)]
  .map((match) => match[1]);
if (inlineScripts.length < 1) throw new Error('Viewer inline runtime is missing.');

class ClassList {
  constructor() { this.values = new Set(); }
  add(...values) { values.forEach((value) => this.values.add(value)); }
  remove(...values) { values.forEach((value) => this.values.delete(value)); }
  contains(value) { return this.values.has(value); }
}

class ElementStub {
  constructor(tag = 'div', id = '') {
    this.tagName = tag.toUpperCase();
    this.id = id;
    this.children = [];
    this.listeners = new Map();
    this.style = {};
    this.classList = new ClassList();
    this.dataset = {};
    this.value = '';
    this.textContent = '';
    this.checked = false;
    this.indeterminate = false;
    this.onclick = null;
    this.hidden = false;
    this._innerHTML = '';
  }
  set className(value) {
    this._className = value;
    this.classList = new ClassList();
    String(value).split(/\s+/).filter(Boolean).forEach((item) => this.classList.add(item));
  }
  get className() { return this._className || ''; }
  set innerHTML(value) {
    this._innerHTML = String(value);
    this.children = [];
  }
  get innerHTML() { return this._innerHTML; }
  addEventListener(name, callback) {
    const callbacks = this.listeners.get(name) || [];
    callbacks.push(callback);
    this.listeners.set(name, callbacks);
  }
  dispatch(name, extra = {}) {
    const event = { target: this, key: '', stopPropagation() {}, preventDefault() {}, ...extra };
    for (const callback of this.listeners.get(name) || []) callback(event);
    if (name === 'click' && typeof this.onclick === 'function') this.onclick(event);
  }
  appendChild(child) { this.children.push(child); return child; }
  prepend(child) { this.children.unshift(child); return child; }
  setAttribute(name, value) {
    if (name === 'class') this.className = value;
    else if (name.startsWith('data-')) this.dataset[name.slice(5)] = String(value);
    else this[name] = String(value);
  }
  getAttribute(name) { return this[name] ?? null; }
  contains(target) { return target === this || this.children.includes(target); }
  closest(selector) { return selector.startsWith('.') && this.classList.contains(selector.slice(1)) ? this : null; }
}

const elementIds = [
  'graph', 'search', 'search-results', 'info-content', 'legend', 'select-all-cb',
  'fit-graph', 'zoom-in', 'zoom-out', 'reset-overview', 'view-state',
  'routing-summary', 'routing-toggle', 'routing-list',
];
const elements = new Map(elementIds.map((id) => [id, new ElementStub('div', id)]));
elements.get('search').tagName = 'INPUT';
elements.get('select-all-cb').tagName = 'INPUT';
elements.get('routing-toggle').setAttribute('aria-expanded', 'false');
elements.get('routing-toggle').textContent = 'Show recent routes';
elements.get('routing-list').hidden = true;
const created = [];
const documentListeners = new Map();
const documentStub = {
  getElementById(id) {
    if (!elements.has(id)) elements.set(id, new ElementStub('div', id));
    return elements.get(id);
  },
  createElement(tag) {
    const element = new ElementStub(tag);
    created.push(element);
    return element;
  },
  addEventListener(name, callback) {
    const callbacks = documentListeners.get(name) || [];
    callbacks.push(callback);
    documentListeners.set(name, callbacks);
  },
  querySelectorAll(selector) {
    if (!selector.startsWith('.')) return [];
    const className = selector.slice(1);
    return created.filter((element) => element.classList.contains(className));
  },
};

class DataSetStub {
  constructor(items = []) { this.items = new Map(); this.add(items); }
  add(items) {
    for (const item of Array.isArray(items) ? items : [items]) this.items.set(item.id, { ...item });
  }
  clear() { this.items.clear(); }
  get(id) {
    if (id === undefined) return [...this.items.values()].map((item) => ({ ...item }));
    return this.items.get(id) ? { ...this.items.get(id) } : null;
  }
  update(items) {
    for (const item of Array.isArray(items) ? items : [items]) {
      this.items.set(item.id, { ...(this.items.get(item.id) || {}), ...item });
    }
  }
}

let activeNetwork = null;
class NetworkStub {
  constructor(_container, data) {
    this.data = data;
    this.handlers = new Map();
    this.scale = 1;
    this.fitCalls = 0;
    activeNetwork = this;
  }
  on(name, callback) { this.handlers.set(name, callback); }
  once(name, callback) { if (name === 'stabilized') callback(); else this.handlers.set(name, callback); }
  setOptions() {}
  stabilize() {}
  fit() { this.fitCalls += 1; }
  focus() {}
  selectNodes() {}
  getScale() { return this.scale; }
  moveTo(options) { if (options.scale) this.scale = options.scale; }
  getPositions(ids) { return Object.fromEntries(ids.map((id, index) => [id, { x: index, y: index }])); }
  getConnectedNodes(nodeId) {
    const result = new Set();
    for (const edge of this.data.edges.get()) {
      if (edge.from === nodeId) result.add(edge.to);
      if (edge.to === nodeId) result.add(edge.from);
    }
    return [...result];
  }
}

const visStub = { DataSet: DataSetStub, Network: NetworkStub };
const windowStub = { matchMedia: () => ({ matches: false }) };
const execute = new Function('vis', 'document', 'window', 'requestAnimationFrame', inlineScripts[0]);
execute(visStub, documentStub, windowStub, (callback) => callback());

if (!activeNetwork) throw new Error('Viewer did not create a graph network.');
if (!elements.get('routing-summary').textContent) throw new Error('Routing evidence panel did not render a status summary.');
elements.get('routing-toggle').dispatch('click');
if (elements.get('routing-toggle').getAttribute('aria-expanded') !== 'true' || elements.get('routing-list').hidden) throw new Error('Routing evidence toggle did not expand the receipt list.');
elements.get('routing-toggle').dispatch('click');
if (elements.get('routing-toggle').getAttribute('aria-expanded') !== 'false' || !elements.get('routing-list').hidden) throw new Error('Routing evidence toggle did not collapse the receipt list.');
const overviewNodeCount = activeNetwork.data.nodes.get().length;
const overviewEdgeCount = activeNetwork.data.edges.get().length;
if (overviewNodeCount < 2 || overviewEdgeCount < 1) throw new Error('Architecture overview is empty.');
const overviewNodes = activeNetwork.data.nodes.get();
if (!overviewNodes.some((node) => node._display_label && node.label === node._display_label)) {
  throw new Error('Viewer did not expose display labels for disambiguated graph nodes.');
}
const repeatedOwnerLabels = overviewNodes
  .map((node) => String(node.label || ''))
  .filter((label) => {
    const parts = label.split(' · ').map((part) => part.trim().toLowerCase());
    return parts.length === 2 && parts[0] && parts[0] === parts[1];
  });
if (repeatedOwnerLabels.length) {
  throw new Error(`Overview contains repeated owner labels: ${repeatedOwnerLabels.slice(0, 3).join(', ')}`);
}
const summaryDuplicateLabels = overviewNodes
  .map((node) => String(node.label || ''))
  .filter((label) => /\b(overview|supporting nodes)\b/i.test(label));
if (summaryDuplicateLabels.length) {
  throw new Error(`Overview contains duplicate summary nodes: ${summaryDuplicateLabels.slice(0, 3).join(', ')}`);
}
const hiddenOverviewLabels = overviewNodes.filter((node) =>
  ['architecture-root', 'architecture-owner', 'architecture-cluster'].includes(String(node._file_type || '')) &&
  (!node.font || Number(node.font.size) <= 0)
);
if (hiddenOverviewLabels.length) {
  throw new Error(`Overview hides architecture labels: ${hiddenOverviewLabels.slice(0, 3).map((node) => node.label).join(', ')}`);
}

const search = elements.get('search');
const results = elements.get('search-results');
search.value = searchQuery;
search.dispatch('input');
const result = results.children.find((element) => element.textContent.toLowerCase().includes(searchQuery.toLowerCase()));
if (!result) throw new Error(`Full graph search did not find ${searchQuery}.`);
result.dispatch('click');
const neighborhoodOpened = elements.get('view-state').textContent.startsWith('Neighborhood:');
const focusedInFullView = elements.get('info-content').innerHTML.toLowerCase().includes(searchQuery.toLowerCase());
if (!neighborhoodOpened && !focusedInFullView) {
  throw new Error('Selecting a graph result neither opened a neighborhood nor focused the full graph node.');
}
if (activeNetwork.data.nodes.get().length < 2 || activeNetwork.data.edges.get().length < 1) {
  throw new Error('Selected graph result has no relationship evidence.');
}
const neighborhoodNodeCount = activeNetwork.data.nodes.get().length;
const neighborhoodEdgeCount = activeNetwork.data.edges.get().length;

elements.get('zoom-in').dispatch('click');
if (activeNetwork.getScale() <= 1) throw new Error('Zoom in control did not change the viewport scale.');
elements.get('zoom-out').dispatch('click');
elements.get('fit-graph').dispatch('click');
if (activeNetwork.fitCalls < 1) throw new Error('Fit control did not invoke the graph viewport.');

elements.get('reset-overview').dispatch('click');
if (!elements.get('view-state').textContent.startsWith('Architecture overview')) {
  throw new Error('Overview control did not restore the architecture view.');
}
if (activeNetwork.data.nodes.get().length !== overviewNodeCount || activeNetwork.data.edges.get().length !== overviewEdgeCount) {
  throw new Error('Overview control did not restore the original bounded graph.');
}

search.value = '__ueef_no_such_graph_node__';
search.dispatch('input');
if (!results.innerHTML.includes('No matching nodes')) throw new Error('No-results search state is missing.');

console.log(JSON.stringify({
  status: 'PASS',
  overviewNodes: overviewNodeCount,
  overviewEdges: overviewEdgeCount,
  neighborhoodNodes: neighborhoodNodeCount,
  neighborhoodEdges: neighborhoodEdgeCount,
  selectionMode: neighborhoodOpened ? 'neighborhood' : 'full-graph-focus',
  fullSearch: 'PASS',
  controls: 'PASS',
  routingToggle: 'PASS',
  noResults: 'PASS',
}));
