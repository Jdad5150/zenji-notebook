import type { DirectoryEntry } from './types';

const mockFs: Record<string, DirectoryEntry[]> = {
	'/': [
		{ name: 'home', path: '/home', isDirectory: true },
		{ name: 'projects', path: '/projects', isDirectory: true },
		{ name: 'tmp', path: '/tmp', isDirectory: true }
	],
	'/home': [
		{ name: 'user', path: '/home/user', isDirectory: true },
		{ name: '.bashrc', path: '/home/.bashrc', isDirectory: false, size: 3400 }
	],
	'/home/user': [
		{ name: 'documents', path: '/home/user/documents', isDirectory: true },
		{ name: 'notebooks', path: '/home/user/notebooks', isDirectory: true },
		{ name: 'notes.txt', path: '/home/user/notes.txt', isDirectory: false, size: 1200 }
	],
	'/home/user/notebooks': [
		{ name: 'analysis.znb', path: '/home/user/notebooks/analysis.znb', isDirectory: false, size: 45000 },
		{ name: 'ml-project.znb', path: '/home/user/notebooks/ml-project.znb', isDirectory: false, size: 128000 },
		{ name: 'scratch.znb', path: '/home/user/notebooks/scratch.znb', isDirectory: false, size: 8200 }
	],
	'/home/user/documents': [
		{ name: 'readme.md', path: '/home/user/documents/readme.md', isDirectory: false, size: 2400 },
		{ name: 'data', path: '/home/user/documents/data', isDirectory: true }
	],
	'/home/user/documents/data': [
		{ name: 'dataset.csv', path: '/home/user/documents/data/dataset.csv', isDirectory: false, size: 5400000 },
		{ name: 'config.json', path: '/home/user/documents/data/config.json', isDirectory: false, size: 340 }
	],
	'/projects': [
		{ name: 'zenji', path: '/projects/zenji', isDirectory: true },
		{ name: 'experiments', path: '/projects/experiments', isDirectory: true }
	],
	'/projects/zenji': [
		{ name: 'main.znb', path: '/projects/zenji/main.znb', isDirectory: false, size: 67000 },
		{ name: 'utils.zig', path: '/projects/zenji/utils.zig', isDirectory: false, size: 12000 },
		{ name: 'src', path: '/projects/zenji/src', isDirectory: true }
	],
	'/tmp': []
};

export async function fetchDirectory(path: string): Promise<DirectoryEntry[]> {
	// Simulate network delay
	await new Promise((r) => setTimeout(r, 150));
	return mockFs[path] ?? [];
}
