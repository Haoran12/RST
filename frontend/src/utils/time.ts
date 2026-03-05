function pad(value: number, width: number = 2): string {
  return String(value).padStart(width, "0");
}

export function toLocalIsoString(date: Date = new Date()): string {
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());
  const hours = pad(date.getHours());
  const minutes = pad(date.getMinutes());
  const seconds = pad(date.getSeconds());
  const millis = pad(date.getMilliseconds(), 3);

  const offsetMinutes = -date.getTimezoneOffset();
  const sign = offsetMinutes >= 0 ? "+" : "-";
  const offsetAbs = Math.abs(offsetMinutes);
  const offsetHours = pad(Math.floor(offsetAbs / 60));
  const offsetRemainMinutes = pad(offsetAbs % 60);

  return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}.${millis}${sign}${offsetHours}:${offsetRemainMinutes}`;
}

const ISO_WITH_TIME_RE =
  /^(\d{4}-\d{2}-\d{2})[T\s](\d{2}:\d{2}:\d{2})(\.\d+)?(?:\s?(Z|[+\-]\d{2}:?\d{2}))?$/i;
const UTC_WORD_SUFFIX_RE = /\sUTC$/i;

function normalizeTimestampInput(raw: string): string {
  const trimmed = raw.trim();
  if (!trimmed) {
    return "";
  }

  const utcWordNormalized = UTC_WORD_SUFFIX_RE.test(trimmed)
    ? `${trimmed.replace(UTC_WORD_SUFFIX_RE, "")}Z`
    : trimmed;
  const match = ISO_WITH_TIME_RE.exec(utcWordNormalized);
  if (!match) {
    return utcWordNormalized;
  }

  const datePart = match[1];
  const timePart = match[2];
  const fractionPart = match[3] ?? "";
  const zonePartRaw = match[4] ?? "";
  const fractionNormalized =
    fractionPart.length > 4 ? `.${fractionPart.slice(1, 4)}` : fractionPart;
  const zonePart =
    zonePartRaw.length === 5 && /^[+\-]\d{4}$/.test(zonePartRaw)
      ? `${zonePartRaw.slice(0, 3)}:${zonePartRaw.slice(3)}`
      : zonePartRaw.toUpperCase();

  return `${datePart}T${timePart}${fractionNormalized}${zonePart}`;
}

export function parseTimestamp(value: string | number | Date | null | undefined): Date | null {
  if (value === null || value === undefined) {
    return null;
  }
  if (value instanceof Date) {
    return Number.isNaN(value.getTime()) ? null : value;
  }
  if (typeof value === "number") {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  const normalized = normalizeTimestampInput(value);
  if (!normalized) {
    return null;
  }
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }
  return parsed;
}

export function formatTimestampLocal(
  value: string | number | Date | null | undefined,
  fallback: string = "-",
): string {
  const parsed = parseTimestamp(value);
  if (!parsed) {
    if (typeof value === "string" && value.trim()) {
      return value;
    }
    return fallback;
  }
  return parsed.toLocaleString();
}

export function timestampToEpochMs(value: string | number | Date | null | undefined): number {
  const parsed = parseTimestamp(value);
  return parsed ? parsed.getTime() : Number.NaN;
}
