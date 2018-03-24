extends Node

const REPLACEMENT_MAP = {
	"&reg": "©",
	"&trade": "™"
}


static func Render(black_card, white_cards):
	var split = black_card.text.split("_")
	var resulting_bbcode = ""
	for i in range(split.size()):
		resulting_bbcode += split[i]
		if i < white_cards.size():
			var word = white_cards[i]
			if i + 1 < split.size():
				if word.length() > 1:
					word = word.substr(0, word.length() - 1)
			resulting_bbcode += " [color=#00FF00]%s[/color]" % word
		if i == (split.size() - 1) and split.size() < white_cards.size():
			for j in range(white_cards.size()):
				if j > i:
					resulting_bbcode += " [color=#00FF00]%s[/color]" % white_cards[j]
			
	resulting_bbcode = resulting_bbcode.replace("<br>", "\n")
	for src in REPLACEMENT_MAP:
		resulting_bbcode = resulting_bbcode.replace(src, REPLACEMENT_MAP[src])
	return resulting_bbcode