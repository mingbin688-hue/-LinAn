import {DatabaseSync} from 'node:sqlite';
import fs from 'node:fs';
export function localD1(file=':memory:'){
 const db=new DatabaseSync(file);db.exec('PRAGMA journal_mode=WAL');
 db.exec('CREATE TABLE IF NOT EXISTS __local_migrations(name TEXT PRIMARY KEY)');
 for(const filename of fs.readdirSync('drizzle').filter(n=>n.endsWith('.sql'))){if(!db.prepare('SELECT name FROM __local_migrations WHERE name=?').get(filename)){db.exec(fs.readFileSync('drizzle/'+filename,'utf8'));db.prepare('INSERT INTO __local_migrations VALUES(?)').run(filename)}}
 const wrapper={prepare(sql){const statement=db.prepare(sql);let values=[];return {bind(...args){values=args;return this},async first(){return statement.get(...values)||null},async run(){const r=statement.run(...values);return {success:true,meta:{changes:Number(r.changes)}}}}},close(){db.close()}};
 return wrapper;
}
