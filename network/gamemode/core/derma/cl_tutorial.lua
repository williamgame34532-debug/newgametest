local PANEL = {}

function PANEL:Init()
	local Sc = NETWORK.util.Scale

	NETWORK.gui.tutorial = self

	self.alpha = 0
	self.step = 1
	self.steps = {}
	self.bClosing = false

	self:SetSize(math.min(Sc(560), math.Round(ScrW() * 0.86)),
		math.min(Sc(230), math.Round(ScrH() * 0.86)))
	self:MakePopup()

	self.back = self:Add("nwActionButton")
	self.back:SetLabel(L("tutorBack"))
	self.back.DoClick = function()
		self:SetStep(self.step - 1)
	end

	self.next = self:Add("nwActionButton")
	self.next:SetPrimary(true)
	self.next.DoClick = function()
		if (self.step >= #self.steps) then
			self:Finish()

			return
		end

		self:SetStep(self.step + 1)
	end

	self.skip = self:Add("nwActionButton")
	self.skip:SetLabel(L("tutorSkip"))
	self.skip.DoClick = function()
		self:Finish()
	end
end

function PANEL:OnRemove()
	if (NETWORK.gui.tutorial == self) then
		NETWORK.gui.tutorial = nil
	end
end

function PANEL:Setup(id, steps)
	self.id = id
	self.steps = steps

	self:SetStep(1)
	self:Reposition()
end

function PANEL:Reposition()
	local Sc = NETWORK.util.Scale

	self:SetPos(math.Round((ScrW() - self:GetWide()) * 0.5), ScrH() - self:GetTall() - Sc(80))
end

function PANEL:SetStep(step)
	local Sc = NETWORK.util.Scale

	self.step = math.Clamp(step, 1, #self.steps)

	local data = self.steps[self.step]

	self.title = NETWORK.util.Upper(data.title or "")
	self.lines = NETWORK.util.WrapText(data.text or "", "nwChat", self:GetWide() - Sc(56), 4)

	self.next:SetLabel(self.step >= #self.steps and L("tutorDone") or L("tutorNext"))
	self.back:SetMouseInputEnabled(self.step > 1)

	NETWORK.sound.Click()
end

function PANEL:Finish()
	if (self.id) then
		RunConsoleCommand("network_tutorial_" .. self.id, "1")
	end

	self.bClosing = true

	self:SetMouseInputEnabled(false)
end

function PANEL:PerformLayout(width, height)
	local Sc = NETWORK.util.Scale
	local buttonWidth = Sc(150)
	local y = height - Sc(52)

	self.back:SetSize(buttonWidth, Sc(38))
	self.back:SetPos(Sc(24), y)

	self.skip:SetSize(buttonWidth, Sc(38))
	self.skip:SetPos(math.Round((width - buttonWidth) * 0.5), y)

	self.next:SetSize(buttonWidth, Sc(38))
	self.next:SetPos(width - buttonWidth - Sc(24), y)
end

function PANEL:Think()
	self.alpha = NETWORK.util.Approach(self.alpha, self.bClosing and 0 or 1, 10)

	self:SetAlpha(math.Round(self.alpha * 255))

	if (self.bClosing and self.alpha < 0.02) then
		self:Remove()
	end
end

function PANEL:OnKeyCodePressed(key)
	if (key == KEY_ESCAPE) then
		self:Finish()
	end
end

function PANEL:Paint(width, height)
	local Sc = NETWORK.util.Scale
	local theme = NETWORK.theme
	local util = NETWORK.util
	local alpha = self.alpha

	util.DrawBlur(self, 5 * alpha, 0.3)

	draw.RoundedBox(Sc(12), 0, 0, width, height, Color(8, 12, 19, 250 * alpha))
	draw.RoundedBoxEx(Sc(12), 0, 0, width, Sc(6), ColorAlpha(theme.accent, 240 * alpha),
		true, true, false, false)

	local counter = self.step .. " / " .. #self.steps

	util.DrawTextSpaced(counter, "nwHudSmall", width - Sc(24) -
		util.TextSpacedSize(counter, "nwHudSmall", Sc(3)), Sc(32),
		ColorAlpha(theme.textFaint, 230 * alpha), Sc(3), TEXT_ALIGN_CENTER)

	util.DrawTextSpaced(self.title or "", "nwTab", Sc(24), Sc(32),
		ColorAlpha(theme.text, 252 * alpha), Sc(4), TEXT_ALIGN_CENTER)

	local y = Sc(66)

	for i = 1, #(self.lines or {}) do
		draw.SimpleText(self.lines[i], "nwChat", Sc(24), y,
			ColorAlpha(theme.textDim, 240 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

		y = y + Sc(24)
	end

	local dotY = height - Sc(70)

	for i = 1, #self.steps do
		local bActive = i == self.step

		util.DrawCircle(Sc(28) + (i - 1) * Sc(18), dotY, bActive and Sc(5) or Sc(3),
			ColorAlpha(bActive and theme.accent or theme.line, (bActive and 250 or 120) * alpha))
	end
end

vgui.Register("nwTutorial", PANEL, "EditablePanel")

NETWORK.gui.tutorials = {}

NETWORK.gui.tutorials.dialogue = {
	{
		title = "Редактор диалогов",
		text = "Здесь собираются разговоры с NPC. Диалог состоит из узлов: " ..
			"узел — это реплика NPC и список ответов игрока."
	},
	{
		title = "Шаг 1. Идентификатор",
		text = "Слева сверху впишите идентификатор латиницей, например worker. " ..
			"По нему диалог будет привязан к NPC. Рядом — название, его увидите в списке."
	},
	{
		title = "Шаг 2. Первый узел",
		text = "Нажмите «Новый узел». Появится стартовый узел greeting с готовым " ..
			"ответом. Выделите его и справа впишите, что говорит NPC."
	},
	{
		title = "Шаг 3. Ответы",
		text = "Кнопка «Добавить ответ» создаёт вариант для игрока. " ..
			"Выделите ответ, чтобы поменять его текст в панели справа."
	},
	{
		title = "Шаг 4. Связи",
		text = "Чтобы ответ вёл к другому узлу: нажмите на оранжевый кружок справа " ..
			"от ответа, затем на нужный узел. Узлы подсветятся зелёным."
	},
	{
		title = "Шаг 5. Выдача задания",
		text = "Выделите ответ вроде «Я возьмусь» и нажмите жёлтую кнопку " ..
			"«Задание: выдать». Она создаст задание, привяжет его к ответу и сразу " ..
			"сделает узел, куда NPC ответит после согласия."
	},
	{
		title = "Шаг 6. Сдача задания",
		text = "Добавьте в стартовый узел ещё один ответ и нажмите зелёную кнопку " ..
			"«Задание: сдать». Она пометит ответ как сдачу и создаст узел с " ..
			"благодарностью. Этот ответ игрок увидит только когда всё соберёт."
	},
	{
		title = "Шаг 7. Сохранение",
		text = "Нажмите «Сохранить». Затем наведитесь на NPC, зажмите C, " ..
			"выберите «Настроить NPC» и укажите ваш диалог в списке."
	},
	{
		title = "Управление",
		text = "ЛКМ по узлу — тащить. ПКМ — двигать холст. Escape — отменить связь " ..
			"или закрыть. Кнопка «Открыть» показывает все сохранённые диалоги."
	}
}

function NETWORK.gui.OpenTutorial(id, bForce)
	local steps = NETWORK.gui.tutorials[id]

	if (!steps) then
		return
	end

	local convar = GetConVar("network_tutorial_" .. id)

	if (!bForce and convar and convar:GetBool()) then
		return
	end

	if (IsValid(NETWORK.gui.tutorial)) then
		NETWORK.gui.tutorial:Remove()
	end

	local panel = vgui.Create("nwTutorial")

	panel:Setup(id, steps)

	return panel
end

for id in pairs(NETWORK.gui.tutorials) do
	CreateClientConVar("network_tutorial_" .. id, "0", true, false,
		"Обучение уже показано")
end

concommand.Add("network_tutorial_reset", function()
	for id in pairs(NETWORK.gui.tutorials) do
		RunConsoleCommand("network_tutorial_" .. id, "0")
	end

	NETWORK.gui.Notify(L("tutorReset"), NETWORK.theme.accentSoft)
end)
