import type { DirectoryEntry } from './types';

export async function fetchDirectory(path: string): Promise<DirectoryEntry[]> {
	const res = await fetch(`/api/contents?path=${encodeURIComponent(path)}`);
	if (!res.ok) return [];
	return res.json();
}
