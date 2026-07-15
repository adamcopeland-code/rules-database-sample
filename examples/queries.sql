-- Example queries for the NFL 2023 sample slice.

-- 1. The rulebook as a tree: Rule 12 (Player Conduct) and everything under it.
SELECT printf('%.*s%s', depth * 2, '                ', COALESCE(label, '')) AS outline,
       unit_type, heading
FROM rule
WHERE path_label = '12' OR path_label LIKE '12.%'
ORDER BY rule_id
LIMIT 30;

-- 2. Structure of the edition: node counts by unit type and depth.
SELECT unit_type, depth, COUNT(*) AS nodes
FROM rule
GROUP BY unit_type, depth
ORDER BY depth, nodes DESC;

-- 3. The longest rules by original token count (counts predate truncation).
SELECT path_label, heading, token_count
FROM rule
WHERE unit_type IN ('rule', 'article', 'section')
ORDER BY token_count DESC
LIMIT 10;

-- 4. Every defined term in the 2023 rulebook.
SELECT path_label, heading
FROM rule
WHERE unit_type = 'definition'
ORDER BY path_label
LIMIT 25;

-- 5. Full-text search (run the FTS rebuild from the README first).
SELECT r.path_label, r.heading, snippet(rule_fts, 1, '[', ']', ' ... ', 8) AS hit
FROM rule_fts JOIN rule r ON r.rule_id = rule_fts.rowid
WHERE rule_fts MATCH 'timeout NEAR injury'
ORDER BY rank
LIMIT 10;
