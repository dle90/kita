package common

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/url"
	"time"

	"github.com/kitaenglish/backend/internal/config"
	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

type Storage struct {
	client *minio.Client
	bucket string
}

func NewStorage(ctx context.Context, cfg config.MinIOConfig) (*Storage, error) {
	// Strip https:// or http:// prefix if present — MinIO client wants just the host
	endpoint := cfg.Endpoint
	if len(endpoint) > 8 && endpoint[:8] == "https://" {
		endpoint = endpoint[8:]
		cfg.UseSSL = true
	} else if len(endpoint) > 7 && endpoint[:7] == "http://" {
		endpoint = endpoint[7:]
	}

	client, err := minio.New(endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
		Region: "auto", // Required for Cloudflare R2
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create storage client: %w", err)
	}

	// Check if bucket exists; create only if it doesn't
	exists, err := client.BucketExists(ctx, cfg.Bucket)
	if err != nil {
		return nil, fmt.Errorf("failed to check bucket: %w", err)
	}
	if !exists {
		if err := client.MakeBucket(ctx, cfg.Bucket, minio.MakeBucketOptions{Region: "auto"}); err != nil {
			return nil, fmt.Errorf("failed to create bucket: %w", err)
		}
		log.Printf("Created bucket: %s", cfg.Bucket)
	}

	log.Printf("Connected to object storage (%s)", endpoint)
	return &Storage{client: client, bucket: cfg.Bucket}, nil
}

func (s *Storage) UploadFile(ctx context.Context, key string, reader io.Reader, size int64, contentType string) (string, error) {
	_, err := s.client.PutObject(ctx, s.bucket, key, reader, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return "", fmt.Errorf("failed to upload file: %w", err)
	}
	return fmt.Sprintf("/%s/%s", s.bucket, key), nil
}

func (s *Storage) GetFileURL(ctx context.Context, key string) (string, error) {
	presignedURL, err := s.client.PresignedGetObject(ctx, s.bucket, key, 24*time.Hour, url.Values{})
	if err != nil {
		return "", fmt.Errorf("failed to get presigned URL: %w", err)
	}
	return presignedURL.String(), nil
}

// ObjectExists returns true if the object is present in the bucket.
func (s *Storage) ObjectExists(ctx context.Context, key string) (bool, error) {
	_, err := s.client.StatObject(ctx, s.bucket, key, minio.StatObjectOptions{})
	if err != nil {
		resp := minio.ToErrorResponse(err)
		if resp.Code == "NoSuchKey" || resp.StatusCode == 404 {
			return false, nil
		}
		return false, fmt.Errorf("stat object: %w", err)
	}
	return true, nil
}

// GetObjectBytes reads an object fully into memory. Suitable for small files (< few MB).
func (s *Storage) GetObjectBytes(ctx context.Context, key string) ([]byte, error) {
	obj, err := s.client.GetObject(ctx, s.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, fmt.Errorf("get object: %w", err)
	}
	defer obj.Close()
	data, err := io.ReadAll(obj)
	if err != nil {
		return nil, fmt.Errorf("read object: %w", err)
	}
	return data, nil
}
