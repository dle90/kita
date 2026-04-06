package content

import (
	"context"
	"encoding/json"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ContentRepository interface {
	GetVocabulary(ctx context.Context, dayNumber int, category string) ([]*Vocabulary, error)
	GetVocabularyByID(ctx context.Context, id uuid.UUID) (*Vocabulary, error)
	GetVocabularyByIDs(ctx context.Context, ids []uuid.UUID) ([]*Vocabulary, error)
	GetSentences(ctx context.Context, dayNumber int) ([]*Sentence, error)
	GetSessionTemplates(ctx context.Context, dayNumber int, level string) ([]*SessionTemplate, error)
	InsertVocabulary(ctx context.Context, vocab *Vocabulary) error
	InsertSentence(ctx context.Context, sentence *Sentence) error
	InsertSessionTemplate(ctx context.Context, tmpl *SessionTemplate) error
	CountVocabulary(ctx context.Context) (int, error)
	CountSessionTemplates(ctx context.Context) (int, error)
}

type pgContentRepository struct {
	pool *pgxpool.Pool
}

func NewContentRepository(pool *pgxpool.Pool) ContentRepository {
	return &pgContentRepository{pool: pool}
}

func (r *pgContentRepository) GetVocabulary(ctx context.Context, dayNumber int, category string) ([]*Vocabulary, error) {
	query := `SELECT id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, target_phonemes, common_l1_errors
		FROM vocabulary WHERE 1=1`
	args := []interface{}{}
	argIdx := 1

	if dayNumber > 0 {
		query += ` AND day_number = $` + itoa(argIdx)
		args = append(args, dayNumber)
		argIdx++
	}
	if category != "" {
		query += ` AND category = $` + itoa(argIdx)
		args = append(args, category)
		argIdx++
	}
	_ = argIdx
	query += ` ORDER BY day_number, difficulty`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return scanVocabularyRows(rows)
}

func (r *pgContentRepository) GetVocabularyByID(ctx context.Context, id uuid.UUID) (*Vocabulary, error) {
	v := &Vocabulary{}
	var phonemesJSON, errorsJSON []byte
	err := r.pool.QueryRow(ctx,
		`SELECT id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, target_phonemes, common_l1_errors
		 FROM vocabulary WHERE id = $1`, id,
	).Scan(&v.ID, &v.Word, &v.TranslationVI, &v.PhoneticIPA, &v.AudioURL, &v.ImageURL, &v.Category, &v.DayNumber, &v.Difficulty, &phonemesJSON, &errorsJSON)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	json.Unmarshal(phonemesJSON, &v.TargetPhonemes)
	json.Unmarshal(errorsJSON, &v.CommonL1Errors)
	return v, nil
}

func (r *pgContentRepository) GetVocabularyByIDs(ctx context.Context, ids []uuid.UUID) ([]*Vocabulary, error) {
	if len(ids) == 0 {
		return nil, nil
	}
	rows, err := r.pool.Query(ctx,
		`SELECT id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, target_phonemes, common_l1_errors
		 FROM vocabulary WHERE id = ANY($1)`, ids,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	return scanVocabularyRows(rows)
}

func scanVocabularyRows(rows pgx.Rows) ([]*Vocabulary, error) {
	var result []*Vocabulary
	for rows.Next() {
		v := &Vocabulary{}
		var phonemesJSON, errorsJSON []byte
		if err := rows.Scan(&v.ID, &v.Word, &v.TranslationVI, &v.PhoneticIPA, &v.AudioURL, &v.ImageURL, &v.Category, &v.DayNumber, &v.Difficulty, &phonemesJSON, &errorsJSON); err != nil {
			return nil, err
		}
		json.Unmarshal(phonemesJSON, &v.TargetPhonemes)
		json.Unmarshal(errorsJSON, &v.CommonL1Errors)
		result = append(result, v)
	}
	return result, nil
}

func (r *pgContentRepository) GetSentences(ctx context.Context, dayNumber int) ([]*Sentence, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, text, translation_vi, audio_url, difficulty, day_number, vocabulary_ids
		 FROM sentences WHERE day_number = $1 ORDER BY difficulty`, dayNumber,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Sentence
	for rows.Next() {
		s := &Sentence{}
		var vocabIDsJSON []byte
		if err := rows.Scan(&s.ID, &s.Text, &s.TranslationVI, &s.AudioURL, &s.Difficulty, &s.DayNumber, &vocabIDsJSON); err != nil {
			return nil, err
		}
		json.Unmarshal(vocabIDsJSON, &s.VocabularyIDs)
		result = append(result, s)
	}
	return result, nil
}

func (r *pgContentRepository) GetSessionTemplates(ctx context.Context, dayNumber int, level string) ([]*SessionTemplate, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, day_number, level, phase, activity_type, config, sort_order, vocabulary_ids, sentence_ids
		 FROM session_templates WHERE day_number = $1 AND level = $2 ORDER BY sort_order`, dayNumber, level,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*SessionTemplate
	for rows.Next() {
		t := &SessionTemplate{}
		var vocabIDsJSON, sentIDsJSON []byte
		if err := rows.Scan(&t.ID, &t.DayNumber, &t.Level, &t.Phase, &t.ActivityType, &t.Config, &t.SortOrder, &vocabIDsJSON, &sentIDsJSON); err != nil {
			return nil, err
		}
		json.Unmarshal(vocabIDsJSON, &t.VocabularyIDs)
		json.Unmarshal(sentIDsJSON, &t.SentenceIDs)
		result = append(result, t)
	}
	return result, nil
}

func (r *pgContentRepository) InsertVocabulary(ctx context.Context, vocab *Vocabulary) error {
	phonemesJSON, _ := json.Marshal(vocab.TargetPhonemes)
	errorsJSON, _ := json.Marshal(vocab.CommonL1Errors)
	_, err := r.pool.Exec(ctx,
		`INSERT INTO vocabulary (id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, target_phonemes, common_l1_errors)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
		 ON CONFLICT (word) DO NOTHING`,
		vocab.ID, vocab.Word, vocab.TranslationVI, vocab.PhoneticIPA, vocab.AudioURL, vocab.ImageURL,
		vocab.Category, vocab.DayNumber, vocab.Difficulty, phonemesJSON, errorsJSON,
	)
	return err
}

func (r *pgContentRepository) InsertSentence(ctx context.Context, sentence *Sentence) error {
	vocabIDsJSON, _ := json.Marshal(sentence.VocabularyIDs)
	_, err := r.pool.Exec(ctx,
		`INSERT INTO sentences (id, text, translation_vi, audio_url, difficulty, day_number, vocabulary_ids)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT DO NOTHING`,
		sentence.ID, sentence.Text, sentence.TranslationVI, sentence.AudioURL,
		sentence.Difficulty, sentence.DayNumber, vocabIDsJSON,
	)
	return err
}

func (r *pgContentRepository) InsertSessionTemplate(ctx context.Context, tmpl *SessionTemplate) error {
	vocabIDsJSON, _ := json.Marshal(tmpl.VocabularyIDs)
	sentIDsJSON, _ := json.Marshal(tmpl.SentenceIDs)
	_, err := r.pool.Exec(ctx,
		`INSERT INTO session_templates (id, day_number, level, phase, activity_type, config, sort_order, vocabulary_ids, sentence_ids)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		 ON CONFLICT DO NOTHING`,
		tmpl.ID, tmpl.DayNumber, tmpl.Level, tmpl.Phase, tmpl.ActivityType,
		tmpl.Config, tmpl.SortOrder, vocabIDsJSON, sentIDsJSON,
	)
	return err
}

func (r *pgContentRepository) CountVocabulary(ctx context.Context) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM vocabulary`).Scan(&count)
	return count, err
}

func (r *pgContentRepository) CountSessionTemplates(ctx context.Context) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM session_templates`).Scan(&count)
	return count, err
}

func itoa(i int) string {
	return string(rune('0' + i))
}
