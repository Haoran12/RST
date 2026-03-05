from __future__ import annotations

from app.models import generate_id
from app.models.lore import (
    ActiveFormUpdate,
    CharacterCreate,
    CharacterData,
    CharacterFile,
    CharacterForm,
    CharacterListResponse,
    CharacterMemory,
    CharacterReorder,
    CharacterUpdate,
    ConsolidateResult,
    FormCreate,
    FormUpdate,
    LoreBatchItem,
    LoreBatchUpdate,
    LoreCategory,
    LoreEntry,
    LoreEntryCreate,
    LoreEntryListResponse,
    LoreEntryReorder,
    LoreEntryUpdate,
    MemoryCreate,
    MemoryListResponse,
    MemoryUpdate,
    SchedulerPromptTemplate,
    SchedulerTemplateUpdate,
)
from app.services.session_service import get_session_dir, get_session_storage
from app.storage.lore_store import LoreStore
from app.time_utils import now_local


class LoreError(RuntimeError):
    pass


class LoreNotFoundError(LoreError):
    pass


class CharacterNotFoundError(LoreError):
    pass


class FormNotFoundError(LoreError):
    pass


class MemoryNotFoundError(LoreError):
    pass


class LoreValidationError(LoreError):
    pass


class LoreService:
    """Business layer for Lore data manipulation."""

    def _store(self, session_name: str) -> LoreStore:
        # Reuse session validation from existing session service.
        get_session_storage(session_name)
        return LoreStore(get_session_dir(session_name))

    def _normalize_tags(self, tags: list[str] | None) -> list[str]:
        if not tags:
            return []
        deduped: list[str] = []
        seen: set[str] = set()
        for raw in tags:
            tag = raw.strip()
            if not tag or tag in seen:
                continue
            seen.add(tag)
            deduped.append(tag)
        return deduped

    def _rebuild_index(self, store: LoreStore) -> None:
        store.rebuild_index()

    def create_entry(self, session_name: str, payload: LoreEntryCreate) -> LoreEntry:
        if payload.category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise LoreValidationError("Entry category cannot be character or memory")

        now = now_local()
        entry = LoreEntry(
            id=generate_id(),
            name=payload.name,
            category=payload.category,
            content=payload.content,
            disabled=payload.disabled,
            constant=payload.constant,
            tags=self._normalize_tags(payload.tags),
            created_at=now,
            updated_at=now,
        )
        store = self._store(session_name)
        store.add_entry(entry)
        self._rebuild_index(store)
        return entry

    def get_entry(self, session_name: str, entry_id: str) -> LoreEntry | CharacterData:
        store = self._store(session_name)
        found = store.find_entry(entry_id)
        if found is not None:
            return found[0]

        character_file = store.load_character(entry_id)
        if character_file is not None:
            return character_file.data

        raise LoreNotFoundError(f"Lore entry '{entry_id}' not found")

    def update_entry(self, session_name: str, entry_id: str, payload: LoreEntryUpdate) -> LoreEntry:
        store = self._store(session_name)
        updates = payload.model_dump(exclude_unset=True)
        if "tags" in updates:
            updates["tags"] = self._normalize_tags(updates.get("tags"))

        updated = store.update_entry(entry_id, updates)
        if updated is None:
            raise LoreNotFoundError(f"Lore entry '{entry_id}' not found")
        self._rebuild_index(store)
        return updated

    def delete_entry(self, session_name: str, entry_id: str) -> None:
        store = self._store(session_name)
        deleted = store.delete_entry(entry_id)
        if not deleted:
            raise LoreNotFoundError(f"Lore entry '{entry_id}' not found")
        self._rebuild_index(store)

    def list_entries(
        self,
        session_name: str,
        category: LoreCategory | None = None,
    ) -> list[LoreEntry]:
        store = self._store(session_name)
        if category is None:
            entries: list[LoreEntry] = []
            for cat in (
                LoreCategory.WORLD_BASE,
                LoreCategory.SOCIETY,
                LoreCategory.PLACE,
                LoreCategory.FACTION,
                LoreCategory.SKILLS,
                LoreCategory.OTHERS,
                LoreCategory.PLOT,
            ):
                entries.extend(store.load_category_file(cat).entries)
            return entries

        if category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise LoreValidationError("Use character routes for character/memory data")
        return list(store.load_category_file(category).entries)

    def batch_update(self, session_name: str, payload: LoreBatchUpdate) -> list[LoreEntry]:
        store = self._store(session_name)
        updated: list[LoreEntry] = []
        for item in payload.updates:
            updates: dict[str, object] = {}
            if item.disabled is not None:
                updates["disabled"] = item.disabled
            if item.constant is not None:
                updates["constant"] = item.constant
            if not updates:
                continue
            entry = store.update_entry(item.entry_id, updates)
            if entry is not None:
                updated.append(entry)
        self._rebuild_index(store)
        return updated

    def reorder_entries(self, session_name: str, payload: LoreEntryReorder) -> list[LoreEntry]:
        if payload.category in {LoreCategory.CHARACTER, LoreCategory.MEMORY}:
            raise LoreValidationError("Use character routes for character/memory data")

        if len(payload.entry_ids) != len(set(payload.entry_ids)):
            raise LoreValidationError("entry_ids must not contain duplicates")

        store = self._store(session_name)
        lore_file = store.load_category_file(payload.category)
        current_ids = [entry.id for entry in lore_file.entries]
        requested_ids = payload.entry_ids

        if len(current_ids) != len(requested_ids) or set(current_ids) != set(requested_ids):
            raise LoreValidationError("entry_ids must include all entries in the category exactly once")

        entry_map = {entry.id: entry for entry in lore_file.entries}
        lore_file.entries = [entry_map[entry_id] for entry_id in requested_ids]
        store.save_category_file(lore_file)
        self._rebuild_index(store)
        return list(lore_file.entries)

    def list_characters(self, session_name: str) -> list[CharacterData]:
        store = self._store(session_name)
        return store.list_characters()

    def reorder_characters(self, session_name: str, payload: CharacterReorder) -> list[CharacterData]:
        if len(payload.character_ids) != len(set(payload.character_ids)):
            raise LoreValidationError("character_ids must not contain duplicates")

        store = self._store(session_name)
        characters = store.list_characters()
        current_ids = [item.character_id for item in characters]
        requested_ids = payload.character_ids

        if len(current_ids) != len(requested_ids) or set(current_ids) != set(requested_ids):
            raise LoreValidationError("character_ids must include all characters exactly once")

        character_files: dict[str, CharacterFile] = {}
        for character_id in requested_ids:
            char_file = store.load_character(character_id)
            if char_file is None:
                raise CharacterNotFoundError(f"Character '{character_id}' not found")
            character_files[character_id] = char_file

        now = now_local()
        reordered: list[CharacterData] = []
        for index, character_id in enumerate(requested_ids):
            char_file = character_files[character_id]
            updated = char_file.data.model_copy(
                update={
                    "sort_order": index,
                    "updated_at": now,
                }
            )
            store.save_character(CharacterFile(data=updated, version=char_file.version))
            reordered.append(updated)

        self._rebuild_index(store)
        return reordered

    def create_character(self, session_name: str, payload: CharacterCreate) -> CharacterData:
        store = self._store(session_name)
        now = now_local()
        existing = store.list_characters()
        next_sort_order = max((item.sort_order for item in existing), default=-1) + 1
        default_form = CharacterForm(
            form_id=generate_id(),
            form_name="默认形态",
            is_default=True,
        )
        character = CharacterData(
            character_id=generate_id(),
            name=payload.name,
            race=payload.race,
            gender=payload.gender,
            birth=payload.birth,
            homeland=payload.homeland,
            aliases=payload.aliases,
            role=payload.role,
            faction=payload.faction,
            objective=payload.objective,
            personality=payload.personality,
            relationship=payload.relationship,
            memories=[],
            forms=[default_form],
            active_form_id=default_form.form_id,
            tags=self._normalize_tags(payload.tags),
            sort_order=next_sort_order,
            disabled=payload.disabled,
            constant=payload.constant,
            created_at=now,
            updated_at=now,
        )
        store.save_character(CharacterFile(data=character, version=1))
        self._rebuild_index(store)
        return character

    def get_character(self, session_name: str, character_id: str) -> CharacterData:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")
        return char_file.data

    def update_character(
        self,
        session_name: str,
        character_id: str,
        payload: CharacterUpdate,
    ) -> CharacterData:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")

        updates = payload.model_dump(exclude_unset=True)
        if "tags" in updates:
            updates["tags"] = self._normalize_tags(updates.get("tags"))
        updates["updated_at"] = now_local()

        updated_data = char_file.data.model_copy(update=updates)
        store.save_character(CharacterFile(data=updated_data, version=char_file.version))
        self._rebuild_index(store)
        return updated_data

    def delete_character(self, session_name: str, character_id: str) -> None:
        store = self._store(session_name)
        deleted = store.delete_character(character_id)
        if not deleted:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")
        self._rebuild_index(store)

    def add_form(self, session_name: str, character_id: str, payload: FormCreate) -> CharacterForm:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")

        form = CharacterForm(
            form_id=generate_id(),
            form_name=payload.form_name,
            is_default=payload.is_default,
            physique=payload.physique,
            features=payload.features,
            vitality_max=payload.vitality_max,
            strength=payload.strength,
            mana_potency=payload.mana_potency,
            toughness=payload.toughness,
            weak=payload.weak,
            resist=payload.resist,
            element=payload.element,
            skills=payload.skills,
            penetration=payload.penetration,
        )

        forms = list(char_file.data.forms)
        if form.is_default:
            forms = [item.model_copy(update={"is_default": False}) for item in forms]
        elif not forms:
            form = form.model_copy(update={"is_default": True})

        forms.append(form)
        active_form_id = char_file.data.active_form_id or form.form_id
        if form.is_default:
            active_form_id = form.form_id

        updated = char_file.data.model_copy(
            update={
                "forms": forms,
                "active_form_id": active_form_id,
                "updated_at": now_local(),
            }
        )
        store.save_character(CharacterFile(data=updated, version=char_file.version))
        self._rebuild_index(store)
        return form

    def update_form(
        self,
        session_name: str,
        character_id: str,
        form_id: str,
        payload: FormUpdate,
    ) -> CharacterForm:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")

        updates = payload.model_dump(exclude_unset=True)
        forms: list[CharacterForm] = []
        target: CharacterForm | None = None

        for form in char_file.data.forms:
            if form.form_id != form_id:
                forms.append(form)
                continue
            target = form.model_copy(update=updates)
            forms.append(target)

        if target is None:
            raise FormNotFoundError(f"Form '{form_id}' not found")

        if target.is_default:
            forms = [
                item if item.form_id == target.form_id else item.model_copy(update={"is_default": False})
                for item in forms
            ]
        elif not any(item.is_default for item in forms):
            forms[0] = forms[0].model_copy(update={"is_default": True})

        updated = char_file.data.model_copy(
            update={"forms": forms, "updated_at": now_local()}
        )
        store.save_character(CharacterFile(data=updated, version=char_file.version))
        self._rebuild_index(store)
        return next(item for item in forms if item.form_id == form_id)

    def delete_form(self, session_name: str, character_id: str, form_id: str) -> None:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")

        if len(char_file.data.forms) <= 1:
            raise LoreValidationError("Character must keep at least one form")

        forms = [form for form in char_file.data.forms if form.form_id != form_id]
        if len(forms) == len(char_file.data.forms):
            raise FormNotFoundError(f"Form '{form_id}' not found")

        if not any(form.is_default for form in forms):
            forms[0] = forms[0].model_copy(update={"is_default": True})

        active_form_id = char_file.data.active_form_id
        if active_form_id == form_id:
            active_form_id = next((form.form_id for form in forms if form.is_default), forms[0].form_id)

        updated = char_file.data.model_copy(
            update={
                "forms": forms,
                "active_form_id": active_form_id,
                "updated_at": now_local(),
            }
        )
        store.save_character(CharacterFile(data=updated, version=char_file.version))
        self._rebuild_index(store)

    def set_active_form(
        self,
        session_name: str,
        character_id: str,
        payload: ActiveFormUpdate,
    ) -> CharacterData:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")

        if not any(form.form_id == payload.form_id for form in char_file.data.forms):
            raise FormNotFoundError(f"Form '{payload.form_id}' not found")

        updated = char_file.data.model_copy(
            update={"active_form_id": payload.form_id, "updated_at": now_local()}
        )
        store.save_character(CharacterFile(data=updated, version=char_file.version))
        self._rebuild_index(store)
        return updated

    def list_memories(self, session_name: str, character_id: str) -> list[CharacterMemory]:
        store = self._store(session_name)
        char_file = store.load_character(character_id)
        if char_file is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")
        return list(char_file.data.memories)

    def add_memory(
        self,
        session_name: str,
        character_id: str,
        payload: MemoryCreate,
    ) -> CharacterMemory:
        store = self._store(session_name)
        if store.load_character(character_id) is None:
            raise CharacterNotFoundError(f"Character '{character_id}' not found")

        memory = CharacterMemory(
            memory_id=generate_id(),
            event=payload.event,
            importance=payload.importance,
            tags=self._normalize_tags(payload.tags),
            known_by=payload.known_by,
            plot_event_id=payload.plot_event_id,
            is_consolidated=False,
            created_at=now_local(),
        )
        store.add_memory(character_id, memory)
        self._rebuild_index(store)
        return memory

    def update_memory(
        self,
        session_name: str,
        character_id: str,
        memory_id: str,
        payload: MemoryUpdate,
    ) -> CharacterMemory:
        store = self._store(session_name)
        updates = payload.model_dump(exclude_unset=True)
        if "tags" in updates:
            updates["tags"] = self._normalize_tags(updates.get("tags"))
        memory = store.update_memory(character_id, memory_id, updates)
        if memory is None:
            raise MemoryNotFoundError(f"Memory '{memory_id}' not found")
        self._rebuild_index(store)
        return memory

    def delete_memory(self, session_name: str, character_id: str, memory_id: str) -> None:
        store = self._store(session_name)
        deleted = store.delete_memory(character_id, memory_id)
        if not deleted:
            raise MemoryNotFoundError(f"Memory '{memory_id}' not found")
        self._rebuild_index(store)

    def get_scheduler_template(self, session_name: str) -> SchedulerPromptTemplate:
        store = self._store(session_name)
        return store.load_scheduler_template()

    def update_scheduler_template(
        self,
        session_name: str,
        payload: SchedulerTemplateUpdate,
    ) -> SchedulerPromptTemplate:
        store = self._store(session_name)
        template = store.load_scheduler_template()
        updates = payload.model_dump(exclude_unset=True)
        updated = template.model_copy(update=updates)
        store.save_scheduler_template(updated)
        return updated


lore_service = LoreService()


__all__ = [
    "LoreError",
    "LoreNotFoundError",
    "CharacterNotFoundError",
    "FormNotFoundError",
    "MemoryNotFoundError",
    "LoreValidationError",
    "LoreService",
    "lore_service",
]
