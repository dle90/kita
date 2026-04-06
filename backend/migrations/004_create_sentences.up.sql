CREATE TABLE sentences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    text TEXT NOT NULL,
    translation_vi TEXT NOT NULL,
    audio_url VARCHAR(500) NOT NULL DEFAULT '',
    difficulty INTEGER NOT NULL DEFAULT 1 CHECK (difficulty >= 1 AND difficulty <= 3),
    day_number INTEGER NOT NULL CHECK (day_number >= 1 AND day_number <= 7),
    vocabulary_ids JSONB NOT NULL DEFAULT '[]'
);

CREATE INDEX idx_sentences_day ON sentences(day_number);
CREATE INDEX idx_sentences_difficulty ON sentences(difficulty);
