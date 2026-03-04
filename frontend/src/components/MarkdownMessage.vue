<template>
  <div class="message-markdown" v-html="renderedHtml"></div>
</template>

<script setup lang="ts">
import MarkdownIt from "markdown-it";
import hljs from "highlight.js";
import { computed } from "vue";

const props = defineProps<{
  content: string;
}>();

const QUOTED_TEXT_PATTERN = /“([^”\n]+)”|"([^"\n]+)"/g;
const SKIPPED_TAGS = new Set(["code", "pre"]);
const SCENE_ESCAPED_RE = /&lt;scene&gt;([\s\S]*?)&lt;\/scene&gt;/gi;
const SCENE_FIELD_RE = /^(time|location|characters)\s*[:：]\s*(.+)$/i;

function escapeHtml(raw: string): string {
  return raw
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;");
}

function decodeHtmlEntities(raw: string): string {
  if (!raw || typeof document === "undefined") {
    return raw;
  }
  const textarea = document.createElement("textarea");
  textarea.innerHTML = raw;
  return textarea.value;
}

function parseSceneFields(raw: string): { time: string; location: string; characters: string } {
  const parsed = {
    time: "",
    location: "",
    characters: "",
  };

  for (const line of raw.split("\n")) {
    const match = line.trim().match(SCENE_FIELD_RE);
    if (!match) {
      continue;
    }
    const key = match[1].toLowerCase() as keyof typeof parsed;
    parsed[key] = match[2].trim();
  }

  return parsed;
}

function buildSceneHtml(fields: { time: string; location: string; characters: string }): string {
  const primary: string[] = [];
  if (fields.time) {
    primary.push(fields.time);
  }
  if (fields.location) {
    primary.push(fields.location);
  }
  const mainLine = primary.join(" · ");
  if (!mainLine && !fields.characters) {
    return "";
  }

  let html = `<span class="scene-tag">`;
  html += `<span class="scene-tag__main">📍 ${escapeHtml(mainLine || "场景更新")}</span>`;
  if (fields.characters) {
    html += `<span class="scene-tag__characters">${escapeHtml(fields.characters)}</span>`;
  }
  html += `</span>`;
  return html;
}

function wrapQuotedTextInHtml(html: string): string {
  if (!html || typeof document === "undefined") {
    return html;
  }
  const template = document.createElement("template");
  template.innerHTML = html;

  const replaceQuotedSegments = (node: Text): void => {
    const text = node.nodeValue ?? "";
    QUOTED_TEXT_PATTERN.lastIndex = 0;
    let cursor = 0;
    let matched = false;
    const fragment = document.createDocumentFragment();

    for (let found = QUOTED_TEXT_PATTERN.exec(text); found; found = QUOTED_TEXT_PATTERN.exec(text)) {
      matched = true;
      const start = found.index;
      const fullText = found[0];
      if (start > cursor) {
        fragment.append(document.createTextNode(text.slice(cursor, start)));
      }
      const wrapped = document.createElement("span");
      wrapped.className = "md-quoted-text";
      wrapped.textContent = fullText;
      fragment.append(wrapped);
      cursor = start + fullText.length;
    }

    if (!matched) {
      return;
    }
    if (cursor < text.length) {
      fragment.append(document.createTextNode(text.slice(cursor)));
    }
    node.parentNode?.replaceChild(fragment, node);
  };

  const walk = (node: Node): void => {
    if (node.nodeType === Node.ELEMENT_NODE) {
      const element = node as HTMLElement;
      if (SKIPPED_TAGS.has(element.tagName.toLowerCase())) {
        return;
      }
      Array.from(element.childNodes).forEach((child) => walk(child));
      return;
    }
    if (node.nodeType === Node.DOCUMENT_FRAGMENT_NODE) {
      Array.from(node.childNodes).forEach((child) => walk(child));
      return;
    }
    if (node.nodeType === Node.TEXT_NODE) {
      replaceQuotedSegments(node as Text);
    }
  };

  walk(template.content);
  return template.innerHTML;
}

const markdown = new MarkdownIt({
  html: false,
  linkify: true,
  breaks: true,
  highlight(code: string, language: string) {
    const normalized = language.trim().toLowerCase();
    if (normalized && hljs.getLanguage(normalized)) {
      try {
        const highlighted = hljs.highlight(code, {
          language: normalized,
          ignoreIllegals: true,
        }).value;
        return `<pre class="hljs"><code>${highlighted}</code></pre>`;
      } catch {
        // Fallback handled below.
      }
    }
    try {
      const highlighted = hljs.highlightAuto(code).value;
      return `<pre class="hljs"><code>${highlighted}</code></pre>`;
    } catch {
      return `<pre class="hljs"><code>${escapeHtml(code)}</code></pre>`;
    }
  },
});

const renderedHtml = computed(() => {
  let html = markdown.render(props.content ?? "");
  html = html.replace(SCENE_ESCAPED_RE, (_, inner: string) => {
    const normalizedInner = inner.replace(/<br\s*\/?>/gi, "\n");
    const decoded = decodeHtmlEntities(normalizedInner).trim();
    const fields = parseSceneFields(decoded);
    return buildSceneHtml(fields);
  });
  return wrapQuotedTextInHtml(html);
});
</script>

<style scoped lang="scss">
.message-markdown {
  color: var(--rst-md-color-paragraph);
  font-size: calc(14px * var(--rst-font-size-scale));
  line-height: 1.7;
  word-break: break-word;
}

.message-markdown :deep(p) {
  margin: 0 0 0.8em;
  color: var(--rst-md-color-paragraph);
}

.message-markdown :deep(p:last-child) {
  margin-bottom: 0;
}

.message-markdown :deep(h1),
.message-markdown :deep(h2),
.message-markdown :deep(h3),
.message-markdown :deep(h4),
.message-markdown :deep(h5),
.message-markdown :deep(h6) {
  margin: 0.9em 0 0.45em;
  line-height: 1.35;
  color: var(--rst-md-color-heading);
}

.message-markdown :deep(h1) {
  font-size: 1.45em;
}

.message-markdown :deep(h2) {
  font-size: 1.3em;
}

.message-markdown :deep(h3) {
  font-size: 1.2em;
}

.message-markdown :deep(em) {
  color: var(--rst-md-color-italic);
}

.message-markdown :deep(.md-quoted-text) {
  color: var(--rst-md-color-quoted);
}

.message-markdown :deep(a) {
  color: var(--rst-accent);
  text-decoration: underline;
}

.message-markdown :deep(ul),
.message-markdown :deep(ol) {
  margin: 0.6em 0 0.8em 1.3em;
}

.message-markdown :deep(ul) {
  list-style: disc;
}

.message-markdown :deep(ol) {
  list-style: decimal;
}

.message-markdown :deep(li + li) {
  margin-top: 0.25em;
}

.message-markdown :deep(blockquote) {
  margin: 0.8em 0;
  padding: 0.35em 0.9em;
  border-left: 3px solid var(--rst-border-color);
  color: var(--rst-text-secondary);
}

.message-markdown :deep(pre) {
  margin: 0.8em 0;
  padding: 12px;
  border-radius: 10px;
  border: 1px solid var(--rst-md-code-border);
  background: var(--rst-md-code-bg);
  overflow-x: auto;
}

.message-markdown :deep(code) {
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
  color: var(--rst-md-code-text);
}

.message-markdown :deep(:not(pre) > code) {
  padding: 0.1em 0.35em;
  border-radius: 4px;
  border: 1px solid var(--rst-md-code-border);
  background: var(--rst-md-code-bg);
}

.message-markdown :deep(.hljs) {
  color: var(--rst-md-code-text);
  background: transparent;
}

.message-markdown :deep(.hljs-keyword),
.message-markdown :deep(.hljs-selector-tag),
.message-markdown :deep(.hljs-subst) {
  color: var(--rst-md-hljs-keyword);
}

.message-markdown :deep(.hljs-string),
.message-markdown :deep(.hljs-meta .hljs-string) {
  color: var(--rst-md-hljs-string);
}

.message-markdown :deep(.hljs-number),
.message-markdown :deep(.hljs-literal) {
  color: var(--rst-md-hljs-number);
}

.message-markdown :deep(.hljs-title),
.message-markdown :deep(.hljs-section),
.message-markdown :deep(.hljs-function .hljs-title) {
  color: var(--rst-md-hljs-title);
}

.message-markdown :deep(.hljs-attr),
.message-markdown :deep(.hljs-attribute) {
  color: var(--rst-md-hljs-attr);
}

.message-markdown :deep(.hljs-comment),
.message-markdown :deep(.hljs-quote) {
  color: var(--rst-md-hljs-comment);
}

.message-markdown :deep(.hljs-built_in),
.message-markdown :deep(.hljs-type),
.message-markdown :deep(.hljs-class .hljs-title) {
  color: var(--rst-md-hljs-built_in);
}

.message-markdown :deep(.hljs-symbol),
.message-markdown :deep(.hljs-bullet),
.message-markdown :deep(.hljs-template-variable),
.message-markdown :deep(.hljs-variable) {
  color: var(--rst-md-hljs-literal);
}

.message-markdown :deep(.scene-tag) {
  display: flex;
  flex-direction: column;
  gap: 2px;
  margin-top: 0.75em;
  padding: 4px 10px;
  border-radius: 8px;
  border: 1px solid var(--rst-border-color);
  background: rgba(var(--rst-accent-rgb), 0.06);
  font-size: 11px;
  line-height: 1.5;
  color: var(--rst-text-secondary);
  opacity: 0.8;
}

.message-markdown :deep(.scene-tag__main) {
  font-weight: 500;
}

.message-markdown :deep(.scene-tag__characters) {
  font-size: 10px;
  opacity: 0.85;
  padding-left: 1.1em;
}
</style>
