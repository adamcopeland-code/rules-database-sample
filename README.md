# Rules of Sport Database: sample

A working sample of the Rules of Sport Database, a structured, full-text-searchable corpus of how sports write and rewrite their rules.

Built and maintained by [Adam Copeland, PhD](https://adamcopeland.co). The full database is private and actively growing; this repo demonstrates its structure and method with one real slice: the NFL 2023 rulebook.

## The full database

- 12 sports, 30 rulebook series, 312 editions cataloged (196 parsed to rule level so far)
- 73,000+ rule nodes with hierarchy (rule, article, section, clause), materialized paths, and per-node token counts
- SQLite with FTS5 full-text search across headings and rule text
- A nightly pipeline parses new editions and runs an eleven-point verification battery (referential integrity, FTS sync, duplicate detection) with backups before every change

The project grew out of a PhD dissertation that applied NLP and statistical models (zero-inflated negative binomial, mixed-effects logistic regression) to 10,277 NFL rules, published as [From Play to Policy](https://doi.org/10.1123/jsm.2024-0370) in the Journal of Sport Management.

## What this sample contains

- `schema.sql`: the real production schema (all 28 objects: tables, FTS5 index, views, triggers)
- `data/nfl_2023_sample.sql`: the NFL 2023 edition parsed to 467 rule nodes with full hierarchy, labels, paths, and original char/token counts
- `examples/queries.sql`: queries to run against the loaded sample

Rule text is truncated to its first sentence. The structure, labels, hierarchy, and counts are the real parsed output; the full text of NFL rulebooks belongs to the NFL, so this sample demonstrates the method without republishing the source. Lineage and change-tracking tables ship empty in the sample.

## Quickstart

```sh
sqlite3 sample.db < schema.sql
sqlite3 sample.db < data/nfl_2023_sample.sql
sqlite3 sample.db "INSERT INTO rule_fts(rule_fts) VALUES('rebuild');"
sqlite3 sample.db < examples/queries.sql
```

Try full-text search:

```sql
SELECT r.path_label, r.heading
FROM rule_fts f JOIN rule r ON r.rule_id = f.rowid
WHERE rule_fts MATCH 'unsportsmanlike' ORDER BY rank LIMIT 10;
```

## License and data terms

Schema and queries: MIT. Sample data: provided for demonstration and research evaluation only. Rulebook text and the rules themselves are the property of the National Football League; this sample reproduces structure, headings, and first sentences only, as factual description of the corpus.

## Contact

Interested in the full database for research or commercial use, or in the methods behind it: [adamcopeland.co/contact](https://adamcopeland.co/contact).
