

var valid_indexes = []
var indexes_to_serve = []

func _init(valid_indexes):
	self.valid_indexes = valid_indexes
	self.indexes_to_serve = shuffle(valid_indexes, valid_indexes.size() * 2.5)

static func shuffle(indexes, amt):
	var new_indexes = []
	for i in indexes:
		new_indexes.append(i)
	
	var size = indexes.size()
	for i in range(amt):
		var idx_1 = randi() % size
		var idx_2 = randi() % size
		var tmp = new_indexes[idx_1]
		new_indexes[idx_1] = new_indexes[idx_2]
		new_indexes[idx_2] = tmp
	return new_indexes
	
func deal():
	return indexes_to_serve.pop_front()

func add_back(idx):
	indexes_to_serve.append(idx)
