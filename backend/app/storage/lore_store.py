from __future__ import annotations

from datetime import datetime
from pathlib import Path

from app.models.lore import (
    ENTRY_CATEGORIES,
    CharacterData,
    CharacterFile,
    CharacterMemory,
    LoreCategory,
    LoreEntry,
    LoreFile,
    LoreIndex,
    LoreIndexEntry,
    SchedulerPromptTemplate,
)
from app.storage.file_io import read_json, write_json


class LoreStore:
    """Manage Lore files for a single session."""

    def __init__(self, session_dir: Path) -> None:
        self.session_dir = session_dir
        self.rst_data_dir = session_dir / "rst_data"
        self.characters_dir = self.rst_data_dir / "characters"
        self.default_world_dir = self.rst_data_dir / "default"
        self.index_dir = self.rst_data_dir / ".index"
        self.index_path = self.index_dir / "index.json"
        self.scheduler_template_path = self.rst_data_dir / "scheduler_template.json"
        self._ensure_layout()

    def _ensure_layout(self) -> None:
        self.characters_dir.mkdir(parents=True, exist_ok=True)
        self.default_world_dir.mkdir(parents=True, exist_ok=True)
        self.index_dir.mkdir(parents=True, exist_ok=True)

    def _character_path(self, character_id: str) -> Path:
        return self.characters_dir / f"{character_id}.json"

    def _category_path(self, category: LoreCategory, world_id: str = "default") -> Path:
        return self.rst_data_dir / world_id / f"{category.value}.json"

    def load_index(self) -> LoreIndex:
        data = read_json(self.index_path)
        if isinstance(data, dict):
            try:
                return LoreIndex.model_validate(data)
            except Exception:
                pass
        index = LoreIndex(items=[], updated_at=datetime.utcnow())
        self.save_index(index)
        return index

    def save_index(self, index: LoreIndex) -> None:
        payload = index.model_copy(update={"updated_at": datetime.utcnow()})
        write_json(self.index_path, payload.model_dump(mode="json"))

    def rebuild_index(self) -> LoreIndex:
        items: list[LoreIndexEntry] = []

        for category in ENTRY_CATEGORIES:
            lore_file = self.load_category_file(category)
            rel_path = str(Path("default") / f"{category.value}.json")
            for entry in lore_file.entries:
                items.append(
                    LoreIndexEntry(
                        entry_id=entry.id,
                        name=entry.name,
                        category=entry.category,
                        tags=list(entry.tags),
                        constant=entry.constant,
                        disabled=entry.disabled,
                        file_path=rel_path,
                        importance=5,
                    )
                )

        for character in self.list_characters():
            rel_path = str(Path("characters") / f"{character.character_id}.json")
            items.append(
                LoreIndexEntry(
                    entry_id=character.character_id,
                    name=character.name,
                    category=LoreCategory.CHARACTER,
                    tags=list(character.tags),
                    constant=character.constant,
                    disabled=character.disabled,
                    file_path=rel_path,
                    importance=5,
                )
            )

            # Register each memory as a searchable index item.
            for memory in character.memories:
                items.append(
                    LoreIndexEntry(
                        entry_id=memory.memory_id,
                        name=memory.event,
                        category=LoreCategory.MEMORY,
                        tags=list(memory.tags),
                        constant=False,
                        disabled=character.disabled,
                        file_path=rel_path,
                        owner=character.character_id,
                        importance=memory.importance,
                    )
                )

        index = LoreIndex(items=items, updated_at=datetime.utcnow())
        self.save_index(index)
        return index

    def load_character(self, character_id: str) -> CharacterFile | None:
        data = read_json(self._character_path(character_id))
        if not isinstance(data, dict):
            return None
        try:
            return CharacterFile.model_validate(data)
        except Exception:
            return None

    def save_character(self, char_file: CharacterFile) -> None:
        char_path = self._character_path(char_file.data.character_id)
        write_json(char_path, char_file.model_dump(mode="json"))

    def delete_character(self, character_id: str) -> bool:
        path = self._character_path(character_id)
        if not path.exists():
            return False
        path.unlink()
        return True

    def list_characters(self) -> list[CharacterData]:
        indexed_results: list[tuple[int, CharacterData]] = []
        for index, path in enumerate(sorted(self.characters_dir.glob("*.json"))):
            data = read_json(path)
            if not isinstance(data, dict):
                continue
            try:
                indexed_results.append((index, CharacterFile.model_validate(data).data))
            except Exception:
                continue
        indexed_results.sort(key=lambda item: (item[1].sort_order, item[0]))
        return [item[1] for item in indexed_results]

    def _empty_lore_file(self, category: LoreCategory, world_id: str) -> LoreFile:
        return LoreFile(world_id=world_id, category=category, entries=[])

    def load_category_file(self, category: LoreCategory, world_id: str = "default") -> LoreFile:
        if category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise ValueError("character/memory does not map to category file")
        path = self._category_path(category, world_id)
        data = read_json(path)
        if isinstance(data, dict):
            try:
                return LoreFile.model_validate(data)
            except Exception:
                pass

        lore_file = self._empty_lore_file(category, world_id)
        self.save_category_file(lore_file)
        return lore_file

    def save_category_file(self, lore_file: LoreFile) -> None:
        path = self._category_path(lore_file.category, lore_file.world_id)
        path.parent.mkdir(parents=True, exist_ok=True)
        write_json(path, lore_file.model_dump(mode="json"))

    def find_entry(self, entry_id: str) -> tuple[LoreEntry, LoreFile] | None:
        for category in ENTRY_CATEGORIES:
            lore_file = self.load_category_file(category)
            for entry in lore_file.entries:
                if entry.id == entry_id:
                    return entry, lore_file
        return None

    def add_entry(self, entry: LoreEntry, world_id: str = "default") -> None:
        lore_file = self.load_category_file(entry.category, world_id)
        lore_file.entries.append(entry)
        self.save_category_file(lore_file)

    def update_entry(self, entry_id: str, updates: dict) -> LoreEntry | None:
        found = self.find_entry(entry_id)
        if found is None:
            return None
        entry, lore_file = found
        merged_updates = {**updates, "updated_at": datetime.utcnow()}
        updated_entry = entry.model_copy(update=merged_updates)

        # If category changes, move the entry across category files.
        if updated_entry.category != lore_file.category:
            lore_file.entries = [item for item in lore_file.entries if item.id != entry_id]
            self.save_category_file(lore_file)

            target_file = self.load_category_file(updated_entry.category, lore_file.world_id)
            target_file.entries.append(updated_entry)
            self.save_category_file(target_file)
            return updated_entry

        lore_file.entries = [updated_entry if item.id == entry_id else item for item in lore_file.entries]
        self.save_category_file(lore_file)
        return updated_entry

    def delete_entry(self, entry_id: str) -> bool:
        for category in ENTRY_CATEGORIES:
            lore_file = self.load_category_file(category)
            before = len(lore_file.entries)
            lore_file.entries = [entry for entry in lore_file.entries if entry.id != entry_id]
            if len(lore_file.entries) != before:
                self.save_category_file(lore_file)
                return True
        return False

    def load_scheduler_template(self) -> SchedulerPromptTemplate:
        data = read_json(self.scheduler_template_path)
        if isinstance(data, dict):
            try:
                return SchedulerPromptTemplate.model_validate(data)
            except Exception:
                pass
        template = SchedulerPromptTemplate()
        self.save_scheduler_template(template)
        return template

    def save_scheduler_template(self, template: SchedulerPromptTemplate) -> None:
        write_json(self.scheduler_template_path, template.model_dump(mode="json"))

    def load_all_entries(self) -> list[LoreEntry | CharacterData]:
        items: list[LoreEntry | CharacterData] = []
        for category in ENTRY_CATEGORIES:
            items.extend(self.load_category_file(category).entries)
        items.extend(self.list_characters())
        return items

    def load_entries_by_ids(self, entry_ids: list[str]) -> list[LoreEntry | CharacterData]:
        entries: list[LoreEntry | CharacterData] = []
        wanted = {entry_id for entry_id in entry_ids}
        if not wanted:
            return entries

        for category in ENTRY_CATEGORIES:
            for entry in self.load_category_file(category).entries:
                if entry.id in wanted:
                    entries.append(entry)

        for character in self.list_characters():
            if character.character_id in wanted:
                entries.append(character)

        return entries

    def load_memory_by_id(self, memory_id: str) -> CharacterMemory | None:
        for character in self.list_characters():
            for memory in character.memories:
                if memory.memory_id == memory_id:
                    return memory
        return None

    def load_character_memories(self, character_id: str) -> list[CharacterMemory]:
        character = self.load_character(character_id)
        if character is None:
            return []
        return list(character.data.memories)

    def add_memory(self, character_id: str, memory: CharacterMemory) -> None:
        char_file = self.load_character(character_id)
        if char_file is None:
            raise ValueError("character not found")
        char_data = char_file.data.model_copy(
            update={
                "memories": [*char_file.data.memories, memory],
                "updated_at": datetime.utcnow(),
            }
        )
        self.save_character(CharacterFile(data=char_data, version=char_file.version))

    def update_memory(self, character_id: str, memory_id: str, updates: dict) -> CharacterMemory | None:
        char_file = self.load_character(character_id)
        if char_file is None:
            return None

        updated_memories: list[CharacterMemory] = []
        updated_target: CharacterMemory | None = None
        for memory in char_file.data.memories:
            if memory.memory_id != memory_id:
                updated_memories.append(memory)
                continue
            merged = memory.model_copy(update=updates)
            updated_target = merged
            updated_memories.append(merged)

        if updated_target is None:
            return None

        char_data = char_file.data.model_copy(
            update={"memories": updated_memories, "updated_at": datetime.utcnow()}
        )
        self.save_character(CharacterFile(data=char_data, version=char_file.version))
        return updated_target

    def delete_memory(self, character_id: str, memory_id: str) -> bool:
        char_file = self.load_character(character_id)
        if char_file is None:
            return False

        memories = [memory for memory in char_file.data.memories if memory.memory_id != memory_id]
        if len(memories) == len(char_file.data.memories):
            return False

        char_data = char_file.data.model_copy(
            update={"memories": memories, "updated_at": datetime.utcnow()}
        )
        self.save_character(CharacterFile(data=char_data, version=char_file.version))
        return True

    def replace_memories(self, character_id: str, memories: list[CharacterMemory]) -> None:
        char_file = self.load_character(character_id)
        if char_file is None:
            raise ValueError("character not found")
        char_data = char_file.data.model_copy(
            update={"memories": list(memories), "updated_at": datetime.utcnow()}
        )
        self.save_character(CharacterFile(data=char_data, version=char_file.version))
