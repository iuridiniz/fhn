import net.http
import json
import runtime
import time
import strings
import os

#flag windows -I../windows_ssl/include -L../windows_ssl/include

const (
	stories_url   = 'https://hacker-news.firebaseio.com/v0/topstories.json'
	item_url_base = 'https://hacker-news.firebaseio.com/v0/item'
	stories_limit = 500
)

struct Story {
	title string
	url   string
	id    int
	time  int
	score int
}

struct SharedData {
mut:
	ids    []int
	cursor int
}

fn (shared self SharedData) do(ch chan string) {
	mut max := 0

	rlock self {
		max = self.ids.len
	}
	
	for {
		mut id := 0
		mut number := 0
		lock self {
			if self.cursor >= self.ids.len {
				break
			}
			id = self.ids[self.cursor]

			self.cursor++
			number = self.cursor
		}
		url := '$item_url_base/${id}.json'
		resp := http.get(url) or { continue }
		story := json.decode(Story, resp.text) or { continue }

		header := '[$number/$max]'
		indent := strings.repeat(` `, header.len)

		mut lines := []string{}
		mut result := ''

		lines << '$header id: $story.id'
		lines << '$indent title: $story.title'
		lines << '$indent url: $story.url'

		for line in lines {
			result += line + '\n'
		}
		ch <- result
	}
}

fn main() {
	mut n_threads := runtime.nr_jobs()
	mut limit := stories_limit

	resp := http.get(stories_url) ?
	ids := json.decode([]int, resp.text) ?

	if os.args.len > 1 && os.args[1].int() > 0 {
		limit = os.args[1].int()
	}
	if limit > ids.len {
		limit = ids.len
	}

	if n_threads > limit {
		n_threads = limit
	}

	cursor := 0
	ch := chan string{cap: n_threads * 10}
	shared sh := SharedData{ids[..limit], cursor}

	mut threads := []thread{}
	rlock sh {
		println('Fetching $sh.ids.len histories with $n_threads vlang threads')
	}
	for _ in 0 .. n_threads {
		threads << go sh.do(ch)
	}
	for {
		select {
			title := <-ch {
				println(title)
			}
			else {
				rlock sh {
					if sh.cursor >= sh.ids.len {
						break
					}
				}
				time.sleep(100 * time.millisecond)
			}
		}
	}
	threads.wait()
	remaining := ch.len
	// println('Remaining ${ch.len}')
	for _ in 0 .. remaining {
		title := <-ch
		println(title)
	}
}
