-- Grammar structures table
CREATE TABLE IF NOT EXISTS grammar_structures (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    description_vi TEXT NOT NULL DEFAULT '',
    template TEXT NOT NULL DEFAULT '',
    cefr_level TEXT NOT NULL DEFAULT 'pre_a1',
    difficulty INT NOT NULL DEFAULT 1,
    prerequisite_ids TEXT[] NOT NULL DEFAULT '{}',
    common_l1_errors JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Patterns table
CREATE TABLE IF NOT EXISTS patterns (
    id TEXT PRIMARY KEY,
    grammar_structure_id TEXT NOT NULL REFERENCES grammar_structures(id),
    template TEXT NOT NULL DEFAULT '',
    template_vi TEXT NOT NULL DEFAULT '',
    communication_function TEXT NOT NULL DEFAULT '',
    slots JSONB NOT NULL DEFAULT '[]',
    difficulty INT NOT NULL DEFAULT 1,
    day_introduced INT NOT NULL DEFAULT 1,
    example_sentences JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_patterns_grammar_structure ON patterns(grammar_structure_id);
CREATE INDEX IF NOT EXISTS idx_patterns_day ON patterns(day_introduced);
CREATE INDEX IF NOT EXISTS idx_patterns_function ON patterns(communication_function);

-- Communication functions table
CREATE TABLE IF NOT EXISTS communication_functions (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    name_vi TEXT NOT NULL DEFAULT '',
    description_vi TEXT NOT NULL DEFAULT '',
    cefr_level TEXT NOT NULL DEFAULT 'pre_a1',
    situations JSONB NOT NULL DEFAULT '[]',
    pattern_ids TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
