DB = {}

local schema = {
    [[CREATE TABLE IF NOT EXISTS `zc_properties` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `label` VARCHAR(64) NOT NULL,
        `interior` VARCHAR(64) NOT NULL,
        `image` VARCHAR(255) DEFAULT NULL,
        `ptype` VARCHAR(8) NOT NULL DEFAULT 'sale',
        `price` INT NOT NULL DEFAULT 0,
        `rent_price` INT NOT NULL DEFAULT 0,
        `rent_days` INT NOT NULL DEFAULT 7,
        `status` VARCHAR(16) NOT NULL DEFAULT 'available',
        `owner` VARCHAR(64) DEFAULT NULL,
        `owner_name` VARCHAR(64) DEFAULT NULL,
        `realtor` VARCHAR(64) DEFAULT NULL,
        `realtor_name` VARCHAR(64) DEFAULT NULL,
        `door` LONGTEXT NOT NULL,
        `street` VARCHAR(128) DEFAULT NULL,
        `locked` TINYINT(1) NOT NULL DEFAULT 1,
        `keyholders` LONGTEXT DEFAULT NULL,
        `sale_price` INT DEFAULT NULL,
        `rent_due` INT DEFAULT NULL,
        `overdue` INT NOT NULL DEFAULT 0,
        `created_at` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `owner` (`owner`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `zc_contracts` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `property_id` INT NOT NULL,
        `ctype` VARCHAR(8) NOT NULL DEFAULT 'sale',
        `price` INT NOT NULL DEFAULT 0,
        `rent_price` INT NOT NULL DEFAULT 0,
        `rent_days` INT NOT NULL DEFAULT 7,
        `buyer` VARCHAR(64) NOT NULL,
        `buyer_name` VARCHAR(64) DEFAULT NULL,
        `realtor` VARCHAR(64) DEFAULT NULL,
        `realtor_name` VARCHAR(64) DEFAULT NULL,
        `status` VARCHAR(16) NOT NULL DEFAULT 'pending',
        `signature` VARCHAR(64) DEFAULT NULL,
        `created_at` INT NOT NULL DEFAULT 0,
        `signed_at` INT DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `buyer` (`buyer`),
        KEY `property_id` (`property_id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `zc_furniture` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `property_id` INT NOT NULL,
        `model` VARCHAR(64) NOT NULL,
        `price` INT NOT NULL DEFAULT 0,
        `placed` TINYINT(1) NOT NULL DEFAULT 0,
        `x` FLOAT DEFAULT NULL, `y` FLOAT DEFAULT NULL, `z` FLOAT DEFAULT NULL,
        `rx` FLOAT DEFAULT 0, `ry` FLOAT DEFAULT 0, `rz` FLOAT DEFAULT 0,
        PRIMARY KEY (`id`),
        KEY `property_id` (`property_id`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `zc_shells` (
        `model` VARCHAR(64) NOT NULL,
        `label` VARCHAR(64) DEFAULT NULL,
        `offset` LONGTEXT DEFAULT NULL,
        PRIMARY KEY (`model`)
    )]],
    [[CREATE TABLE IF NOT EXISTS `zc_payouts` (
        `id` INT NOT NULL AUTO_INCREMENT,
        `identifier` VARCHAR(64) NOT NULL,
        `amount` INT NOT NULL,
        `reason` VARCHAR(128) DEFAULT NULL,
        PRIMARY KEY (`id`),
        KEY `identifier` (`identifier`)
    )]],
}

function DB.Init()
    for _, q in ipairs(schema) do MySQL.query.await(q) end
    -- v1.2: custom / MLO interiors store the inside point
    local col = MySQL.query.await("SHOW COLUMNS FROM `zc_properties` LIKE 'inside'")
    if not col or #col == 0 then
        MySQL.query.await('ALTER TABLE `zc_properties` ADD COLUMN `inside` LONGTEXT DEFAULT NULL')
    end
end

function DB.LoadShells()
    return MySQL.query.await('SELECT * FROM zc_shells') or {}
end

function DB.SaveShell(model, label, offset)
    MySQL.query.await('INSERT INTO zc_shells (`model`, `label`, `offset`) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `offset` = VALUES(`offset`)',
        { model, label, offset and json.encode(offset) or nil })
end

function DB.LoadProperties()
    return MySQL.query.await('SELECT * FROM zc_properties') or {}
end

function DB.LoadContracts()
    -- only keep what the UI needs in memory
    return MySQL.query.await('SELECT * FROM zc_contracts WHERE status = "pending" OR created_at > ?', { os.time() - 86400 * 30 }) or {}
end

function DB.InsertProperty(p)
    return MySQL.insert.await([[INSERT INTO zc_properties
        (label, interior, image, ptype, price, rent_price, rent_days, status, realtor, realtor_name, door, street, locked, keyholders, created_at, inside)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, '[]', ?, ?)]],
        { p.label, p.interior, p.image, p.ptype, p.price, p.rent_price, p.rent_days, p.status,
          p.realtor, p.realtor_name, json.encode(p.door), p.street, p.created_at, p.inside and json.encode(p.inside) or nil })
end

-- Persist the whole in-memory row
function DB.SaveProperty(p)
    MySQL.update.await([[UPDATE zc_properties SET label=?, interior=?, image=?, ptype=?, price=?, rent_price=?, rent_days=?,
        status=?, owner=?, owner_name=?, realtor=?, realtor_name=?, door=?, street=?, locked=?, keyholders=?, sale_price=?,
        rent_due=?, overdue=?, inside=? WHERE id=?]],
        { p.label, p.interior, p.image, p.ptype, p.price, p.rent_price, p.rent_days, p.status, p.owner, p.owner_name,
          p.realtor, p.realtor_name, json.encode(p.door), p.street, p.locked and 1 or 0, json.encode(p.keyholders or {}),
          p.sale_price, p.rent_due, p.overdue or 0, p.inside and json.encode(p.inside) or nil, p.id })
end

function DB.DeleteProperty(id)
    MySQL.query.await('DELETE FROM zc_properties WHERE id = ?', { id })
    MySQL.query.await('DELETE FROM zc_furniture WHERE property_id = ?', { id })
    MySQL.query.await('UPDATE zc_contracts SET status = "cancelled" WHERE property_id = ? AND status = "pending"', { id })
end

function DB.InsertContract(c)
    return MySQL.insert.await([[INSERT INTO zc_contracts
        (property_id, ctype, price, rent_price, rent_days, buyer, buyer_name, realtor, realtor_name, status, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', ?)]],
        { c.property_id, c.ctype, c.price, c.rent_price, c.rent_days, c.buyer, c.buyer_name, c.realtor, c.realtor_name, c.created_at })
end

function DB.UpdateContract(c)
    MySQL.update.await('UPDATE zc_contracts SET status=?, signature=?, signed_at=? WHERE id=?',
        { c.status, c.signature, c.signed_at, c.id })
end

function DB.ContractsForBuyer(identifier)
    return MySQL.query.await('SELECT * FROM zc_contracts WHERE buyer = ? ORDER BY id DESC LIMIT 50', { identifier }) or {}
end

function DB.RecentContracts()
    return MySQL.query.await('SELECT * FROM zc_contracts ORDER BY id DESC LIMIT 150') or {}
end

function DB.AddPayout(identifier, amount, reason)
    MySQL.insert.await('INSERT INTO zc_payouts (identifier, amount, reason) VALUES (?, ?, ?)', { identifier, amount, reason })
end

function DB.TakePayouts(identifier)
    local rows = MySQL.query.await('SELECT * FROM zc_payouts WHERE identifier = ?', { identifier }) or {}
    if #rows > 0 then MySQL.query.await('DELETE FROM zc_payouts WHERE identifier = ?', { identifier }) end
    return rows
end

-- Furniture
function DB.FurnitureFor(propertyId)
    return MySQL.query.await('SELECT * FROM zc_furniture WHERE property_id = ?', { propertyId }) or {}
end

function DB.InsertFurniture(propertyId, model, price)
    return MySQL.insert.await('INSERT INTO zc_furniture (property_id, model, price) VALUES (?, ?, ?)', { propertyId, model, price })
end

function DB.UpdateFurniture(f)
    MySQL.update.await('UPDATE zc_furniture SET placed=?, x=?, y=?, z=?, rx=?, ry=?, rz=? WHERE id=?',
        { f.placed and 1 or 0, f.x, f.y, f.z, f.rx, f.ry, f.rz, f.id })
end

function DB.DeleteFurniture(id)
    MySQL.query.await('DELETE FROM zc_furniture WHERE id = ?', { id })
end

function DB.ClearFurniture(propertyId)
    MySQL.query.await('DELETE FROM zc_furniture WHERE property_id = ?', { propertyId })
end
