package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"runtime"
	"strconv"
	"sync"
)

const (
	storiesUrl   = "https://hacker-news.firebaseio.com/v0/topstories.json"
	itemUrlBase  = "https://hacker-news.firebaseio.com/v0/item"
	storiesLimit = 500
)

type Story struct {
	Title string `json:"title"`
	Url   string `json:"url"`
	Id    int    `json:"id"`
	Time  int    `json:"time"`
	Score int    `json:"score"`
}

type Shared struct {
	Ids    []int
	Cursor int
	mutex  sync.Mutex
}

func numJobs() int {
	jobs, err := strconv.Atoi(os.Getenv("JOBS"))

	if err != nil {
		jobs = runtime.NumCPU()
	}

	if jobs < 1 {
		jobs = runtime.NumCPU()
	}

	return jobs
}

func goStoryThread(sh *Shared, threadId int) {
	var url string
	var story Story
	var err error
	var body []byte
	var resp *http.Response

	max := len(sh.Ids)

	for {
		var id int
		var number int
		{
			sh.mutex.Lock()
			number = sh.Cursor
			sh.Cursor++
			sh.mutex.Unlock()
		}

		if number >= len(sh.Ids) {
			break
		}
		id = sh.Ids[number]

		url = fmt.Sprintf("%s/%d.json", itemUrlBase, id)
		resp, err = http.Get(url)
		if err != nil {
			fmt.Println(url)
			panic(err)
		}
		body, err = ioutil.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			fmt.Println(url)
			panic(err)
		}
		err = json.Unmarshal(body, &story)
		if err != nil {
			fmt.Println(url)
			panic(err)
		}
		output := ""
		output += fmt.Sprintf("[%d/%d] id: %d\n", number+1, max, id)
		output += fmt.Sprintf("    title: %s\n", story.Title)
		output += fmt.Sprintf("    url: %s\n", story.Url)

		fmt.Println(output)
	}
}

func main() {
	var err error
	var body []byte
	var resp *http.Response

	nThreads := numJobs()
	limit := storiesLimit

	resp, err = http.Get(storiesUrl)
	if err != nil {
		panic(err)
	}
	body, err = ioutil.ReadAll(resp.Body)
	resp.Body.Close()
	if err != nil {
		panic(err)
	}
	ids := make([]int, storiesLimit)
	err = json.Unmarshal(body, &ids)
	if err != nil {
		panic(err)
	}

	if len(os.Args) > 1 {
		_limit, err := strconv.Atoi(os.Args[1])
		if err == nil {
			limit = _limit
		}
	}
	if nThreads > limit {
		nThreads = limit
	}

	sh := Shared{Ids: ids[:limit], Cursor: 0}
	wg := sync.WaitGroup{}

	fmt.Printf("Fetching %d stories using %d go threads\n", limit, nThreads)
	for i := 0; i < nThreads; i++ {
		wg.Add(1)
		threadId := i
		go func() {
			goStoryThread(&sh, threadId)
			wg.Done()
		}()
	}
	wg.Wait()

}
