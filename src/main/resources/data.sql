-- Désactivation des contraintes pour permettre le nettoyage (nécessaire pour éviter SQLIntegrityConstraintViolationException)
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE orders;
TRUNCATE TABLE user;
TRUNCATE TABLE admin;
TRUNCATE TABLE product_table;
SET FOREIGN_KEY_CHECKS = 1;

-- Insertion d'un compte admin par défaut (Format Hibernate 6)
INSERT INTO admin (admin_name, admin_email, admin_password, admin_number) 
VALUES ('Super Admin', 'admin@foodfrenzy.com', 'admin123', '+261123456789');

-- Insertion de quelques utilisateurs de test
INSERT INTO user (uname, uemail, upassword, unumber) 
VALUES 
    ('John Doe', 'john@example.com', 'user123', 1234567890),
    ('Jane Smith', 'jane@example.com', 'user123', 9876543210);
