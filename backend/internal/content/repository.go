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

	// Phonemes
	InsertPhoneme(ctx context.Context, p *Phoneme) error
	GetPhonemes(ctx context.Context) ([]*Phoneme, error)
	GetPhonemeByID(ctx context.Context, id string) (*Phoneme, error)
	CountPhonemes(ctx context.Context) (int, error)

	// Grammar & Patterns
	InsertGrammarStructure(ctx context.Context, gs *GrammarStructure) error
	InsertPattern(ctx context.Context, p *Pattern) error
	InsertCommunicationFunction(ctx context.Context, cf *CommunicationFunction) error
	GetGrammarStructures(ctx context.Context) ([]*GrammarStructure, error)
	GetPatterns(ctx context.Context, day int) ([]*Pattern, error)
	GetPatternsByFunction(ctx context.Context, function string) ([]*Pattern, error)
	GetCommunicationFunctions(ctx context.Context) ([]*CommunicationFunction, error)
	CountGrammarStructures(ctx context.Context) (int, error)
	CountPatterns(ctx context.Context) (int, error)
	CountCommunicationFunctions(ctx context.Context) (int, error)
}

type pgContentRepository struct {
	pool *pgxpool.Pool
}

func NewContentRepository(pool *pgxpool.Pool) ContentRepository {
	return &pgContentRepository{pool: pool}
}

func (r *pgContentRepository) GetVocabulary(ctx context.Context, dayNumber int, category string) ([]*Vocabulary, error) {
	query := `SELECT id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, emoji, example_sentence, example_sentence_vi, target_phonemes, common_l1_errors
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
		`SELECT id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, emoji, example_sentence, example_sentence_vi, target_phonemes, common_l1_errors
		 FROM vocabulary WHERE id = $1`, id,
	).Scan(&v.ID, &v.Word, &v.TranslationVI, &v.PhoneticIPA, &v.AudioURL, &v.ImageURL, &v.Category, &v.DayNumber, &v.Difficulty, &v.Emoji, &v.ExampleSentence, &v.ExampleSentenceVI, &phonemesJSON, &errorsJSON)
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
		`SELECT id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, emoji, example_sentence, example_sentence_vi, target_phonemes, common_l1_errors
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
		if err := rows.Scan(&v.ID, &v.Word, &v.TranslationVI, &v.PhoneticIPA, &v.AudioURL, &v.ImageURL, &v.Category, &v.DayNumber, &v.Difficulty, &v.Emoji, &v.ExampleSentence, &v.ExampleSentenceVI, &phonemesJSON, &errorsJSON); err != nil {
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
		`INSERT INTO vocabulary (id, word, translation_vi, phonetic_ipa, audio_url, image_url, category, day_number, difficulty, emoji, example_sentence, example_sentence_vi, target_phonemes, common_l1_errors)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
		 ON CONFLICT (word) DO NOTHING`,
		vocab.ID, vocab.Word, vocab.TranslationVI, vocab.PhoneticIPA, vocab.AudioURL, vocab.ImageURL,
		vocab.Category, vocab.DayNumber, vocab.Difficulty, vocab.Emoji, vocab.ExampleSentence, vocab.ExampleSentenceVI, phonemesJSON, errorsJSON,
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

func (r *pgContentRepository) InsertGrammarStructure(ctx context.Context, gs *GrammarStructure) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO grammar_structures (id, name, description_vi, template, cefr_level, difficulty, prerequisite_ids, common_l1_errors)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
		 ON CONFLICT (id) DO NOTHING`,
		gs.ID, gs.Name, gs.DescriptionVI, gs.Template, gs.CEFRLevel, gs.Difficulty, gs.PrerequisiteIDs, gs.CommonL1Errors,
	)
	return err
}

func (r *pgContentRepository) InsertPattern(ctx context.Context, p *Pattern) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO patterns (id, grammar_structure_id, template, template_vi, communication_function, slots, difficulty, day_introduced, example_sentences)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
		 ON CONFLICT (id) DO NOTHING`,
		p.ID, p.GrammarStructureID, p.Template, p.TemplateVI, p.CommunicationFunction, p.Slots, p.Difficulty, p.DayIntroduced, p.ExampleSentences,
	)
	return err
}

func (r *pgContentRepository) InsertCommunicationFunction(ctx context.Context, cf *CommunicationFunction) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO communication_functions (id, name, name_vi, description_vi, cefr_level, situations, pattern_ids)
		 VALUES ($1, $2, $3, $4, $5, $6, $7)
		 ON CONFLICT (id) DO NOTHING`,
		cf.ID, cf.Name, cf.NameVI, cf.DescriptionVI, cf.CEFRLevel, cf.Situations, cf.PatternIDs,
	)
	return err
}

func (r *pgContentRepository) GetGrammarStructures(ctx context.Context) ([]*GrammarStructure, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, name, description_vi, template, cefr_level, difficulty, prerequisite_ids, common_l1_errors
		 FROM grammar_structures ORDER BY difficulty`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*GrammarStructure
	for rows.Next() {
		gs := &GrammarStructure{}
		if err := rows.Scan(&gs.ID, &gs.Name, &gs.DescriptionVI, &gs.Template, &gs.CEFRLevel, &gs.Difficulty, &gs.PrerequisiteIDs, &gs.CommonL1Errors); err != nil {
			return nil, err
		}
		result = append(result, gs)
	}
	return result, nil
}

func (r *pgContentRepository) GetPatterns(ctx context.Context, day int) ([]*Pattern, error) {
	query := `SELECT id, grammar_structure_id, template, template_vi, communication_function, slots, difficulty, day_introduced, example_sentences
		 FROM patterns`
	args := []interface{}{}
	if day > 0 {
		query += ` WHERE day_introduced = $1`
		args = append(args, day)
	}
	query += ` ORDER BY difficulty, day_introduced`

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Pattern
	for rows.Next() {
		p := &Pattern{}
		if err := rows.Scan(&p.ID, &p.GrammarStructureID, &p.Template, &p.TemplateVI, &p.CommunicationFunction, &p.Slots, &p.Difficulty, &p.DayIntroduced, &p.ExampleSentences); err != nil {
			return nil, err
		}
		result = append(result, p)
	}
	return result, nil
}

func (r *pgContentRepository) GetPatternsByFunction(ctx context.Context, function string) ([]*Pattern, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, grammar_structure_id, template, template_vi, communication_function, slots, difficulty, day_introduced, example_sentences
		 FROM patterns WHERE communication_function = $1 ORDER BY difficulty`, function)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Pattern
	for rows.Next() {
		p := &Pattern{}
		if err := rows.Scan(&p.ID, &p.GrammarStructureID, &p.Template, &p.TemplateVI, &p.CommunicationFunction, &p.Slots, &p.Difficulty, &p.DayIntroduced, &p.ExampleSentences); err != nil {
			return nil, err
		}
		result = append(result, p)
	}
	return result, nil
}

func (r *pgContentRepository) GetCommunicationFunctions(ctx context.Context) ([]*CommunicationFunction, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, name, name_vi, description_vi, cefr_level, situations, pattern_ids
		 FROM communication_functions ORDER BY name`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*CommunicationFunction
	for rows.Next() {
		cf := &CommunicationFunction{}
		if err := rows.Scan(&cf.ID, &cf.Name, &cf.NameVI, &cf.DescriptionVI, &cf.CEFRLevel, &cf.Situations, &cf.PatternIDs); err != nil {
			return nil, err
		}
		result = append(result, cf)
	}
	return result, nil
}

func (r *pgContentRepository) CountGrammarStructures(ctx context.Context) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM grammar_structures`).Scan(&count)
	return count, err
}

// Phoneme repository methods

func (r *pgContentRepository) InsertPhoneme(ctx context.Context, p *Phoneme) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO phonemes (id, symbol, example_word, example_word_vi, graphemes, is_new_for_vietnamese, common_substitution, substitution_vi, mouth_position_vi, difficulty, priority_northern, priority_central, priority_southern, minimal_pairs, practice_words)
		 VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
		 ON CONFLICT (id) DO NOTHING`,
		p.ID, p.Symbol, p.ExampleWord, p.ExampleWordVI, p.Graphemes, p.IsNewForVietnamese,
		p.CommonSubstitution, p.SubstitutionVI, p.MouthPositionVI, p.Difficulty,
		p.PriorityNorthern, p.PriorityCentral, p.PrioritySouthern, p.MinimalPairs, p.PracticeWords,
	)
	return err
}

func (r *pgContentRepository) GetPhonemes(ctx context.Context) ([]*Phoneme, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT id, symbol, example_word, COALESCE(example_word_vi,''), graphemes, is_new_for_vietnamese, COALESCE(common_substitution,''), COALESCE(substitution_vi,''), COALESCE(mouth_position_vi,''), difficulty, priority_northern, priority_central, priority_southern, minimal_pairs, practice_words
		 FROM phonemes ORDER BY difficulty DESC`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var result []*Phoneme
	for rows.Next() {
		p := &Phoneme{}
		if err := rows.Scan(&p.ID, &p.Symbol, &p.ExampleWord, &p.ExampleWordVI, &p.Graphemes, &p.IsNewForVietnamese, &p.CommonSubstitution, &p.SubstitutionVI, &p.MouthPositionVI, &p.Difficulty, &p.PriorityNorthern, &p.PriorityCentral, &p.PrioritySouthern, &p.MinimalPairs, &p.PracticeWords); err != nil {
			return nil, err
		}
		result = append(result, p)
	}
	return result, nil
}

func (r *pgContentRepository) GetPhonemeByID(ctx context.Context, id string) (*Phoneme, error) {
	p := &Phoneme{}
	err := r.pool.QueryRow(ctx,
		`SELECT id, symbol, example_word, COALESCE(example_word_vi,''), graphemes, is_new_for_vietnamese, COALESCE(common_substitution,''), COALESCE(substitution_vi,''), COALESCE(mouth_position_vi,''), difficulty, priority_northern, priority_central, priority_southern, minimal_pairs, practice_words
		 FROM phonemes WHERE id = $1`, id,
	).Scan(&p.ID, &p.Symbol, &p.ExampleWord, &p.ExampleWordVI, &p.Graphemes, &p.IsNewForVietnamese, &p.CommonSubstitution, &p.SubstitutionVI, &p.MouthPositionVI, &p.Difficulty, &p.PriorityNorthern, &p.PriorityCentral, &p.PrioritySouthern, &p.MinimalPairs, &p.PracticeWords)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return p, nil
}

func (r *pgContentRepository) CountPhonemes(ctx context.Context) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM phonemes`).Scan(&count)
	return count, err
}

func (r *pgContentRepository) CountPatterns(ctx context.Context) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM patterns`).Scan(&count)
	return count, err
}

func (r *pgContentRepository) CountCommunicationFunctions(ctx context.Context) (int, error) {
	var count int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM communication_functions`).Scan(&count)
	return count, err
}

func itoa(i int) string {
	return string(rune('0' + i))
}
