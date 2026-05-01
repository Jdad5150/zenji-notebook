export interface DirectoryEntry {
	name: string;
	path: string;
	isDirectory: boolean;
	size?: number;
	modified?: string;
}
