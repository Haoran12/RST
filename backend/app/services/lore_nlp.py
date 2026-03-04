from __future__ import annotations

import re

from app.models.lore import LoreIndexEntry

try:
    import jieba  # type: ignore[import-untyped]
except Exception:  # pragma: no cover
    jieba = None  # type: ignore[assignment]

try:
    from rank_bm25 import BM25Okapi  # type: ignore[import-untyped]
except Exception:  # pragma: no cover
    BM25Okapi = None  # type: ignore[assignment]


_TOKEN_RE = re.compile(r"[\w\u4e00-\u9fff]+", re.UNICODE)


class LoreNlpEngine:
    """BM25-based retriever with a lightweight fallback tokenizer."""

    def __init__(self) -> None:
        self._tokenizer_ready: bool = False
        self._custom_dict: set[str] = set()
        self._bm25: BM25Okapi | None = None
        self._corpus_ids: list[str] = []
        self._entries: dict[str, LoreIndexEntry] = {}
        self._name_to_ids: dict[str, list[str]] = {}
        self._tag_to_ids: dict[str, list[str]] = {}

    def _normalize_lookup_key(self, value: str) -> str:
        return value.strip().lower()

    def _append_index_value(self, index: dict[str, list[str]], key: str, entry_id: str) -> None:
        bucket = index.setdefault(key, [])
        if entry_id not in bucket:
            bucket.append(entry_id)

    def _tokenize(self, text: str) -> list[str]:
        text = text.strip()
        if not text:
            return []

        if jieba is not None:
            return [token for token in jieba.cut(text) if token.strip()]
        return _TOKEN_RE.findall(text.lower())

    def _ensure_custom_words(self, words: set[str]) -> None:
        if jieba is None:
            return
        for word in words:
            cleaned = word.strip()
            if not cleaned or cleaned in self._custom_dict:
                continue
            jieba.add_word(cleaned)
            self._custom_dict.add(cleaned)

    def _entry_text(self, entry: LoreIndexEntry) -> str:
        return f"{entry.name} {' '.join(entry.tags)}"

    def build_index(self, entries: list[LoreIndexEntry]) -> None:
        self._entries = {entry.entry_id: entry for entry in entries}
        custom_words: set[str] = set()
        corpus: list[list[str]] = []
        self._corpus_ids = []
        self._name_to_ids = {}
        self._tag_to_ids = {}

        for entry in entries:
            custom_words.add(entry.name)
            custom_words.update(entry.tags)
            name_key = self._normalize_lookup_key(entry.name)
            if name_key:
                self._append_index_value(self._name_to_ids, name_key, entry.entry_id)
            for tag in entry.tags:
                tag_key = self._normalize_lookup_key(tag)
                if not tag_key:
                    continue
                self._append_index_value(self._tag_to_ids, tag_key, entry.entry_id)

        self._ensure_custom_words(custom_words)
        self._tokenizer_ready = True

        for entry in entries:
            tokens = self._tokenize(self._entry_text(entry))
            if not tokens:
                tokens = [entry.entry_id]
            corpus.append(tokens)
            self._corpus_ids.append(entry.entry_id)

        if BM25Okapi is not None and corpus:
            self._bm25 = BM25Okapi(corpus)
        else:
            self._bm25 = None

    def lookup_by_name(self, name: str) -> list[str]:
        key = self._normalize_lookup_key(name)
        if not key:
            return []
        return list(self._name_to_ids.get(key, []))

    def lookup_by_tag(self, tag: str) -> list[str]:
        key = self._normalize_lookup_key(tag)
        if not key:
            return []
        return list(self._tag_to_ids.get(key, []))

    def lookup_by_name_or_tag(self, value: str) -> list[str]:
        key = self._normalize_lookup_key(value)
        if not key:
            return []
        results: list[str] = []
        seen: set[str] = set()
        for entry_id in self._name_to_ids.get(key, []):
            if entry_id in seen:
                continue
            seen.add(entry_id)
            results.append(entry_id)
        for entry_id in self._tag_to_ids.get(key, []):
            if entry_id in seen:
                continue
            seen.add(entry_id)
            results.append(entry_id)
        return results

    def retrieve(self, query_text: str, top_k: int = 20) -> list[str]:
        if not self._entries:
            return []
        if not self._tokenizer_ready:
            self.build_index(list(self._entries.values()))

        tokens = self._tokenize(query_text)
        if not tokens:
            return []

        if self._bm25 is not None:
            scores = self._bm25.get_scores(tokens)
            ordered = sorted(range(len(scores)), key=lambda i: scores[i], reverse=True)
            results: list[str] = []
            for index in ordered:
                if len(results) >= top_k:
                    break
                if scores[index] <= 0:
                    continue
                results.append(self._corpus_ids[index])
            return results

        # Fallback scoring when BM25 dependency is unavailable.
        query_set = set(tokens)
        ranked: list[tuple[int, str]] = []
        for entry_id, entry in self._entries.items():
            entry_tokens = set(self._tokenize(self._entry_text(entry)))
            score = len(query_set & entry_tokens)
            if score > 0:
                ranked.append((score, entry_id))
        ranked.sort(key=lambda item: item[0], reverse=True)
        return [entry_id for _, entry_id in ranked[:top_k]]

    def update_entry(self, entry: LoreIndexEntry) -> None:
        self._entries[entry.entry_id] = entry
        self.build_index(list(self._entries.values()))

    def remove_entry(self, entry_id: str) -> None:
        if entry_id in self._entries:
            self._entries.pop(entry_id)
            self.build_index(list(self._entries.values()))
