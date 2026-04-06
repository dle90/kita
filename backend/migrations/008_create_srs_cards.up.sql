CREATE TABLE srs_cards (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    kid_id UUID NOT NULL REFERENCES kids(id) ON DELETE CASCADE,
    vocabulary_id UUID NOT NULL REFERENCES vocabulary(id) ON DELETE CASCADE,
    repetitions INTEGER NOT NULL DEFAULT 0,
    ease_factor DOUBLE PRECISION NOT NULL DEFAULT 2.5,
    interval_days INTEGER NOT NULL DEFAULT 1,
    next_review_date TIMESTAMPTZ NOT NULL,
    last_review_date TIMESTAMPTZ,
    last_quality INTEGER NOT NULL DEFAULT 0 CHECK (last_quality >= 0 AND last_quality <= 5),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(kid_id, vocabulary_id)
);

CREATE INDEX idx_srs_cards_kid ON srs_cards(kid_id);
CREATE INDEX idx_srs_cards_kid_due ON srs_cards(kid_id, next_review_date);
CREATE INDEX idx_srs_cards_vocab ON srs_cards(vocabulary_id);
