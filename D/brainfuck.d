extern(C):

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

import std.conv : emplace;

T * alloc(T) ()
{
	T * ptr = cast(T*) malloc(T.sizeof);
	return emplace(ptr);
}

void forget(T) (T * ptr)
{
	free(ptr);
}

T[] alloc_slice(T) (size_t size)
{
	T[] slice = (cast(T*) malloc(T.sizeof * size)[0..size])[0..size];
	for (int i = 0; i < size; i++) {
		emplace(&slice[i]);
	}
	return slice;
}

void copy_slice(T) (T[] dest, T[] source, size_t count)
{
	assert(count <= dest.length);
	assert(count <= source.length);
	for (int i = 0; i < count; i++) {
		dest[i] = source[i];
	}
}

void forget_slice(T) (T[] slice)
{
	free(cast(void*) slice);
}

char[] load_string_from_file(FILE * file)
{
	fseek(file, 0, SEEK_SET);
	size_t size = 0;
	while (fgetc(file) != EOF) size++;
	fseek(file, 0, SEEK_SET);
	char[] str = alloc_slice!char(size + 1);
	str[size] = '\0';
	fread(cast(void*) str, char.sizeof, size, file);
	return str;
}

struct List(T) {
	static const size_t start_capacity = 4;
	
	T[] arr;
	size_t length = 0;
	float growth_factor;
	
	static List make(float growth_factor = 2.0)
	{
		List list;
		list.arr = alloc_slice!T(start_capacity);
		list.growth_factor = growth_factor;
		return list;
	}
	void push(T item)
	{
		if (length >= arr.length) {
			size_t new_capacity = cast(size_t) (arr.length * growth_factor);
			T[] new_arr = alloc_slice!T(new_capacity);
			copy_slice(new_arr, arr, arr.length);
			forget_slice(arr);
			arr = new_arr;
		}
		arr[length++] = item;
	}
	T at(size_t index)
	{
		assert(index < length);
		return arr[index];
	}
	void drop()
	{
		forget_slice(arr);
	}
}

void list_test()
{
	auto list = List!int.make();
	list.push(1);
	list.push(2);
	list.push(3);
	list.push(3);
	list.push(3);
	list.push(3);
	for (int i = 0; i < list.length; i++) {
		printf("%d\n", list.at(i));
	}
	scope(exit) list.drop();
}

struct Stack(T) {
	struct Node {
		T data;
		Node * next;
	}
	Node * head = null;
	void push(T data)
	{
		Node * node = alloc!Node;
		node.data = data;
		node.next = head;
		head = node;
	}
	T pop()
	{
		assert(head);
		Node * ret = head;
		head = ret.next;
		T data = ret.data;
		forget(ret);
		return data;
	}
}

struct Lexer {
	char[] source;
	size_t position = 0;
	
	static Lexer make(char[] source)
	{
		Lexer l;
		l.source = source;
		return l;
	}
	private char this_char()
	{
		if (position >= source.length) {
			return '\0';
		}
		return source[position];
	}
	private void advance()
	{
		if (position < source.length) {
			position++;
		}
	}
	char next_command()
	{
		// Short-circuit if at end of source
		if (position >= source.length) return '\0';
		// Switch on char
		char c = this_char();
		advance();
		switch (c) {
		case '+':
		case '-':
		case '<':
		case '>':
		case '.':
		case ',':
		case '[':
		case ']':
			return c;
		default:
			return next_command();
		}
	}
}

pure int modulo(int x, int l)
{
	if (x >= 0) return x % l;
	return modulo(l + x, l);
}

struct BF_State {
	static const memory_size = 16;
	ubyte[memory_size] memory;
	size_t cursor = 0;
	Stack!(size_t) loop_stack;
	
	static BF_State make()
	{
		BF_State state;
		for (int i = 0; i < memory_size; i++) {
			state.memory[i] = 0;
		}
		return state;
	}
	size_t command(char[] commands, size_t place)
	{
		switch (commands[place]) {
		case '+':
			memory[cursor]++;
			return place + 1;
		case '-':
			memory[cursor]--;
			return place + 1;
		case '>':
			cursor = modulo((cast(int) cursor) + 1, memory_size);
			return place + 1;
		case '<':
			cursor = modulo((cast(int) cursor) - 1, memory_size);
			return place + 1;
		case '[':
			if (memory[cursor] == 0) {
				return place + 1;
			} else {
				loop_stack.push(place);
				return place + 1;
			}
		case ']':
			return place + 1;
		case '.':
			return place + 1;
		case ',':
			return place + 1;
		default:
			assert(false);
		}
	}
	void debug_print()
	{
		foreach (chunk; memory) {
			printf("%d ", chunk);
		}
		printf("\n");
	}
}

int main(int argc, char ** argv)
{
	list_test();
	return 0;
	foreach (filename; argv[1..argc]) {
		FILE * file = fopen(filename, "r");
		char[] source = load_string_from_file(file);
		scope(exit) forget_slice(source);
		fclose(file);
		
		Lexer lexer = Lexer.make(source);

		BF_State bf_state = BF_State.make();
		printf("  ");
		bf_state.debug_print();

		/*
		while (true) {
			char cmd = lexer.next_command();
			if (cmd == '\0') break;
			printf("%c ", cmd);
			bf_state.command(cmd);
			bf_state.debug_print();
			}*/
	}
	return 0;
}
