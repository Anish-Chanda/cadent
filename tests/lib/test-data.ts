import fs from 'node:fs';
import path from 'node:path';

const testDataDir = path.join(__dirname, '..', 'test-data');

export function testDataPath(name: string): string {
  return path.join(testDataDir, name);
}

export function readTestFile(name: string): { name: string; buffer: Buffer } {
  return { name, buffer: fs.readFileSync(testDataPath(name)) };
}
