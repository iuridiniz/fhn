What to do (basic):

 - Download last 500 news from 'https://hacker-news.firebaseio.com/v0/topstories.json' / 'https://hacker-news.firebaseio.com/v0/item'
    - show the headline/url of each item
 - use $NPROC OS threads/green threads
 
What to do (plus):
 - configurable threads / default to NPROC
 - configurable number of headlines / default 500
 - minimal use of no standard libraries
 - crosscompile and run it in windows
 
Challengers
- How to spawn threads
- How to discovery NPROC
- How to sync threads
- How to parse json
- How to do a HTTP fetch
- Trouble with TLS (HTTPS)?

- HACKER NEWS API:
  - https://github.com/HackerNews/API

------------------- 
"Do not communicate by sharing memory; instead, share memory by communicating."
https://github.com/golang/go/wiki/MutexOrChannel
https://medium.com/mindorks/https-medium-com-yashishdua-synchronizing-states-using-mutex-vs-channel-in-go-25e646c83567

Channel (distribute ownership):
- passing ownership of data,
- distributing units of work,
- communicating async results

Mutex (share resources):
- caches,
- state

