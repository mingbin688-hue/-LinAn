import { sqliteTable,text,integer } from 'drizzle-orm/sqlite-core';
export const rooms=sqliteTable('demo_rooms',{
 id:text('id').primaryKey(),
 payload:text('payload').notNull(),
 version:integer('version').notNull().default(1),
 updated:integer('updated').notNull(),
 expires:integer('expires').notNull()
});
