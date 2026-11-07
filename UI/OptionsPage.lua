--[[
Página de opciones
==================

Construye una página de opciones a partir de una lista de filas descritas
como datos, de arriba abajo. Así una sección de clase (UI/ClassPages) solo
dice qué opciones tiene, no cómo se dibujan.

Tipos de fila:
  { kind = "check", label, icon, tooltip, get, set }
        casilla (UI/Checkbox.lua)
  { kind = "checks", items = { { label, icon, tooltip, get, set }, ... } }
        varias casillas en la misma fila, en columnas
  { kind = "header", label }
        título de un grupo de filas
  { kind = "columns", label, columns = { "Título 1", "Título 2" } }
        texto a la izquierda y títulos centrados sobre las columnas de cajas
  { kind = "numbers", label, tooltip, fields = { { get, set, tooltip }, ... } }
        texto a la izquierda y una caja numérica (UI/NumberBox.lua) por columna
  { kind = "note", text }
        texto de ayuda en gris, a lo ancho

  local update = ns.OptionsPage.Build(page, rows)
  update()   -- vuelve a leer todos los valores
]]

local _, ns = ...
local UI = ns.Const.UI

local OptionsPage = {}
ns.OptionsPage = OptionsPage

--------------------------------------------------------------------------------
-- Piezas comunes
--------------------------------------------------------------------------------

local function rowY(index)
    return UI.PAGE_TOP - (index - 1) * UI.ROW_HEIGHT
end

-- Texto a la izquierda de la fila, centrado en su alto.
local function leftLabel(page, y, text, font)
    local label = page:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
    label:SetPoint("LEFT", page, "TOPLEFT", UI.PADDING, y - UI.ROW_HEIGHT / 2)
    label:SetText(text)
    return label
end

-- Centro horizontal de la columna i de cajas numéricas.
local function columnCenter(i)
    return UI.NUMBER_COLUMNS[i] + UI.NUMBER_BOX_WIDTH / 2
end

--------------------------------------------------------------------------------
-- Constructores por tipo de fila
--------------------------------------------------------------------------------
-- Cada uno dibuja la fila a la altura y y devuelve los controles que hay que
-- actualizar (los que tienen :Update()), o nada.

local builders = {}

function builders.checks(page, row, y)
    local controls = {}
    for i, item in ipairs(row.items) do
        local cb = ns.Checkbox.Create(page, item)
        cb:SetPoint("LEFT", page, "TOPLEFT", UI.PADDING + (i - 1) * UI.CHECK_COLUMN_WIDTH, y - UI.ROW_HEIGHT / 2)
        controls[i] = cb
    end
    return controls
end

function builders.check(page, row, y)
    return builders.checks(page, { items = { row } }, y)
end

function builders.header(page, row, y)
    leftLabel(page, y, row.label, "GameFontNormalSmall")
end

function builders.columns(page, row, y)
    builders.header(page, row, y)
    for i, title in ipairs(row.columns) do
        local text = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        text:SetPoint("CENTER", page, "TOPLEFT", columnCenter(i), y - UI.ROW_HEIGHT / 2)
        text:SetText(title)
    end
end

-- Los textos (FontString) no reciben el ratón y no pueden tener tooltip: el de
-- la fila va en cada caja que no traiga uno propio.
function builders.numbers(page, row, y)
    leftLabel(page, y, row.label)
    local controls = {}
    for i, field in ipairs(row.fields) do
        -- Copia para no tocar la descripción de la fila, que es de la sección.
        local opts = { get = field.get, set = field.set, tooltip = field.tooltip or row.tooltip }
        local box = ns.NumberBox.Create(page, opts)
        box:SetPoint("LEFT", page, "TOPLEFT", UI.NUMBER_COLUMNS[i], y - UI.ROW_HEIGHT / 2)
        controls[#controls + 1] = box
    end
    return controls
end

function builders.note(page, row, y)
    local note = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    -- Dos anclas a la misma altura (izquierda y derecha) fijan el ancho; el
    -- alto lo da el propio texto según las líneas que ocupe.
    note:SetPoint("TOPLEFT", page, "TOPLEFT", UI.PADDING, y - UI.ROW_HEIGHT / 4)
    note:SetPoint("TOPRIGHT", page, "TOPRIGHT", -UI.PADDING, y - UI.ROW_HEIGHT / 4)
    note:SetJustifyH("LEFT")
    note:SetText(row.text)
end

--------------------------------------------------------------------------------
-- API del componente
--------------------------------------------------------------------------------

function OptionsPage.Build(page, rows)
    local controls = {}
    for i, row in ipairs(rows) do
        for _, c in ipairs(builders[row.kind](page, row, rowY(i)) or {}) do
            controls[#controls + 1] = c
        end
    end
    return function()
        for _, c in ipairs(controls) do c:Update() end
    end
end
