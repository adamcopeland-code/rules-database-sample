CREATE VIRTUAL TABLE rule_fts USING fts5(
    heading, body_text, content='rule', content_rowid='rule_id'
);
CREATE TABLE sport (
    sport_id          INTEGER PRIMARY KEY,
    name              TEXT NOT NULL UNIQUE,
    slug              TEXT UNIQUE,
    default_structure TEXT CHECK (default_structure IN ('individual','team')),
    description       TEXT
);
CREATE TABLE governing_body (
    body_id       INTEGER PRIMARY KEY,
    name          TEXT NOT NULL,
    abbrev        TEXT,                 -- catalog League code (NFL, NCAAF, IFA, FA, FIFA, NHL, NCAAH, MLB, NCAAB, Golf)
    type          TEXT CHECK (type IN ('professional_league','federation','collegiate','other')),
    country_scope TEXT,
    website       TEXT,
    notes         TEXT
);
CREATE TABLE rulebook_series (
    series_id          INTEGER PRIMARY KEY,
    sport_id           INTEGER NOT NULL REFERENCES sport(sport_id),
    body_id            INTEGER NOT NULL REFERENCES governing_body(body_id),
    name               TEXT NOT NULL,
    level              TEXT CHECK (level IN ('professional','amateur','youth','mixed')),
    gender             TEXT CHECK (gender IN ('men','women','mixed','open')),
    structure          TEXT CHECK (structure IN ('individual','team')),
    competition_system TEXT CHECK (competition_system IN ('open','closed','unknown')) DEFAULT 'unknown',
    notes              TEXT
);
CREATE TABLE rulebook_edition (
    edition_id        INTEGER PRIMARY KEY,
    series_id         INTEGER NOT NULL REFERENCES rulebook_series(series_id),
    year_start        INTEGER NOT NULL,
    year_end          INTEGER,                 -- for season-spanning editions
    edition_label     TEXT,
    publication_date  DATE,
    language          TEXT DEFAULT 'en',
    page_count        INTEGER,
    token_count       INTEGER,
    legacy_catalog_id INTEGER,                 -- existing catalog Unique ID
    canonical_doc_id  INTEGER,                 -- FK added after source_document (see index/trigger note)
    notes             TEXT,
    UNIQUE (series_id, year_start, edition_label)
);
CREATE TABLE source_document (
    doc_id           INTEGER PRIMARY KEY,
    edition_id       INTEGER NOT NULL REFERENCES rulebook_edition(edition_id),
    doc_type         TEXT CHECK (doc_type IN ('original_pdf','ocr_pdf','cleaned_text','structured_json','word_doc','other')),
    relative_path    TEXT NOT NULL,
    file_hash        TEXT,
    byte_size        INTEGER,
    encoding         TEXT,
    processing_stage TEXT,
    source_url       TEXT,
    retrieval_date   DATE,
    is_canonical     INTEGER NOT NULL DEFAULT 0 CHECK (is_canonical IN (0,1)),
    notes            TEXT
);
CREATE TABLE rule_lineage (
    lineage_id      INTEGER PRIMARY KEY,
    series_id       INTEGER NOT NULL REFERENCES rulebook_series(series_id),
    canonical_label TEXT,
    description     TEXT
);
CREATE TABLE rule (
    rule_id        INTEGER PRIMARY KEY,
    edition_id     INTEGER NOT NULL REFERENCES rulebook_edition(edition_id),
    parent_rule_id INTEGER REFERENCES rule(rule_id),
    lineage_id     INTEGER REFERENCES rule_lineage(lineage_id),
    ordinal        INTEGER,
    depth          INTEGER,
    unit_type      TEXT CHECK (unit_type IN ('part','rule','article','section','subsection','clause','item','definition','penalty','note')),
    label          TEXT,
    path_label     TEXT,                 -- materialized path e.g. "12.2.a"
    heading        TEXT,
    body_text      TEXT,
    char_count     INTEGER,
    token_count    INTEGER
);
CREATE TABLE rule_change (
    change_id       INTEGER PRIMARY KEY,
    lineage_id      INTEGER NOT NULL REFERENCES rule_lineage(lineage_id),
    edition_from_id INTEGER REFERENCES rulebook_edition(edition_id),
    edition_to_id   INTEGER REFERENCES rulebook_edition(edition_id),
    from_rule_id    INTEGER REFERENCES rule(rule_id),
    to_rule_id      INTEGER REFERENCES rule(rule_id),
    change_type     TEXT CHECK (change_type IN ('added','removed','reworded','renumbered','moved','split','merged','unchanged')),
    magnitude       REAL,
    summary         TEXT
);
CREATE TABLE concept (
    concept_id        INTEGER PRIMARY KEY,
    name              TEXT NOT NULL UNIQUE,
    definition        TEXT,
    parent_concept_id INTEGER REFERENCES concept(concept_id)
);
CREATE TABLE coding_scheme (
    scheme_id   INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    description TEXT,
    method      TEXT CHECK (method IN ('manual','lexicon','word2vec','topic_model','llm','other')),
    version     TEXT,
    created_by  TEXT
);
CREATE TABLE annotation (
    annotation_id INTEGER PRIMARY KEY,
    rule_id       INTEGER REFERENCES rule(rule_id),
    edition_id    INTEGER REFERENCES rulebook_edition(edition_id),
    span_start    INTEGER,
    span_end      INTEGER,
    concept_id    INTEGER REFERENCES concept(concept_id),
    scheme_id     INTEGER NOT NULL REFERENCES coding_scheme(scheme_id),
    value         REAL,
    label         TEXT,
    confidence    REAL,
    annotator     TEXT,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    notes         TEXT
);
CREATE INDEX idx_series_sport      ON rulebook_series(sport_id);
CREATE INDEX idx_series_body       ON rulebook_series(body_id);
CREATE INDEX idx_edition_series     ON rulebook_edition(series_id);
CREATE INDEX idx_edition_year       ON rulebook_edition(year_start);
CREATE INDEX idx_doc_edition        ON source_document(edition_id);
CREATE INDEX idx_rule_edition       ON rule(edition_id);
CREATE INDEX idx_rule_parent        ON rule(parent_rule_id);
CREATE INDEX idx_rule_lineage       ON rule(lineage_id);
CREATE INDEX idx_change_lineage     ON rule_change(lineage_id);
CREATE INDEX idx_annotation_rule    ON annotation(rule_id);
CREATE INDEX idx_annotation_concept ON annotation(concept_id);
CREATE VIEW v_edition_catalog AS
SELECT  e.edition_id,
        e.legacy_catalog_id      AS unique_id,
        e.year_start             AS year,
        gb.abbrev                AS league,
        s.name                   AS sport,
        CASE rs.level WHEN 'professional' THEN 1 ELSE 0 END AS professional,
        CASE rs.structure WHEN 'individual' THEN 1 ELSE 0 END AS individual,
        CASE rs.gender WHEN 'women' THEN 1 ELSE 0 END        AS womens,
        d.relative_path          AS canonical_file
FROM rulebook_edition e
JOIN rulebook_series rs ON rs.series_id = e.series_id
JOIN sport s            ON s.sport_id = rs.sport_id
JOIN governing_body gb  ON gb.body_id = rs.body_id
LEFT JOIN source_document d ON d.doc_id = e.canonical_doc_id;
