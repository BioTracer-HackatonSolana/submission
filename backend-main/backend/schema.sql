-- BioTracer (MariaDB 10.11+)
--
-- O usuário da API não cria o servidor. Como root:
--   CREATE DATABASE IF NOT EXISTS biotracer CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
--   CREATE USER IF NOT EXISTS 'biotracer'@'localhost' IDENTIFIED BY 'senha';
--   GRANT ALL PRIVILEGES ON biotracer.* TO 'biotracer'@'localhost';
--   FLUSH PRIVILEGES;
--
-- As tabelas abaixo são aplicadas pelo backend na subida (initDb).

CREATE TABLE IF NOT EXISTS nodes (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  role TINYINT UNSIGNED NOT NULL,
  name VARCHAR(120) NOT NULL,
  pubkey VARCHAR(64) NOT NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_nodes_pubkey (pubkey),
  KEY idx_nodes_role (role),
  CONSTRAINT chk_nodes_role CHECK (role IN (0, 1, 2))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS batches (
  id INT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(64) NULL,
  product_name VARCHAR(160) NOT NULL,
  quantity INT UNSIGNED NOT NULL DEFAULT 0,
  unit VARCHAR(32) NOT NULL DEFAULT '',
  expires_at DATE NULL,
  industry_node_id INT UNSIGNED NOT NULL,
  transport_node_id INT UNSIGNED NULL,
  hospital_node_id INT UNSIGNED NULL,
  custody_node_id INT UNSIGNED NOT NULL,
  pda VARCHAR(64) NULL,
  bump TINYINT UNSIGNED NULL,
  chain_status TINYINT UNSIGNED NULL,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_batches_code (code),
  KEY idx_batches_created (created_at),
  CONSTRAINT fk_batches_industry FOREIGN KEY (industry_node_id) REFERENCES nodes (id),
  CONSTRAINT fk_batches_transport FOREIGN KEY (transport_node_id) REFERENCES nodes (id),
  CONSTRAINT fk_batches_hospital FOREIGN KEY (hospital_node_id) REFERENCES nodes (id),
  CONSTRAINT fk_batches_custody FOREIGN KEY (custody_node_id) REFERENCES nodes (id),
  CONSTRAINT chk_batches_status CHECK (chain_status IS NULL OR chain_status BETWEEN 0 AND 4)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS trace_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  batch_id INT UNSIGNED NOT NULL,
  chain_status TINYINT UNSIGNED NOT NULL,
  action TINYINT UNSIGNED NOT NULL,
  node_pubkey VARCHAR(64) NOT NULL,
  chain_timestamp BIGINT NOT NULL,
  tx_signature VARCHAR(128) NOT NULL,
  reversed TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_events_batch (batch_id, id),
  CONSTRAINT fk_events_batch FOREIGN KEY (batch_id) REFERENCES batches (id),
  CONSTRAINT chk_events_status CHECK (chain_status BETWEEN 0 AND 4),
  CONSTRAINT chk_events_action CHECK (action IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
