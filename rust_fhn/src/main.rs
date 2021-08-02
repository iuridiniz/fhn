use serde::{Deserialize, Serialize};

const STORIES_URL: &str = "https://hacker-news.firebaseio.com/v0/topstories.json";
const ITEM_BASE_URL: &str = "https://hacker-news.firebaseio.com/v0/item/";
const STORIES_LIMIT: usize = 500;

#[derive(Serialize, Deserialize, Debug)]
struct Story {
    title: Option<String>,
    url: Option<String>,
    id: Option<u32>,
    time: Option<u32>,
    score: Option<u32>,
    number: Option<usize>,
}

struct Shared {
    ids: Vec<u32>,
    cursor: std::sync::Mutex<usize>,
}

fn do_fetch(tx: std::sync::mpsc::Sender<Option<Story>>, sh: std::sync::Arc<Shared>) {
    loop {
        let i;
        {
            let mut cursor = sh.cursor.lock().unwrap();
            i = *cursor;
            if i >= sh.ids.len() {
                break;
            }
            *cursor += 1;
        }
        let story = || -> Option<Story> {
            let url = ITEM_BASE_URL.to_owned() + &format!("{}.json", sh.ids[i]);
            let resp = reqwest::blocking::get(url).ok()?;
            let mut story = resp.json::<Story>().ok()?;
            story.number = Some(i + 1);
            Some(story)
        }();
        tx.send(story).unwrap();
    }
}

fn print_story(story: Story, max: usize) {
    let header = format!("[{}/{}]", story.number.unwrap(), max);
    let indent = " ".repeat(header.len());

    println!("{} id: {}", header, story.id.unwrap_or_default());
    println!("{} title: {}", indent, story.title.unwrap_or_default());
    println!("{} url: {}", indent, story.url.unwrap_or_default());
    print!("\n");
}

fn nr_jobs() -> usize {
    match std::env::var("JOBS")
        .unwrap_or("0".to_string())
        .parse::<usize>()
    {
        Ok(jobs) if jobs > 0 => jobs,
        _ => num_cpus::get(),
    }
}

fn main() {
    let mut num_threads = nr_jobs();
    let mut limit = STORIES_LIMIT;

    let args: Vec<String> = std::env::args().collect();

    if args.len() > 1 {
        limit = match args[1].parse::<usize>() {
            Ok(arg_limit) if arg_limit > 0 => arg_limit,
            _ => limit,
        }
    }

    let resp = reqwest::blocking::get(STORIES_URL).unwrap();
    assert_eq!(resp.status(), 200);

    let ids = resp.json::<Vec<u32>>().unwrap();
    assert!(ids.len() > 0);

    if ids.len() < limit {
        limit = ids.len();
    }

    if num_threads > limit {
        num_threads = limit;
    }

    let (tx, rx): (
        std::sync::mpsc::Sender<Option<Story>>,
        std::sync::mpsc::Receiver<Option<Story>>,
    ) = std::sync::mpsc::channel();

    let sh = std::sync::Arc::new(Shared {
        ids: ids[0..limit].to_vec(),
        cursor: std::sync::Mutex::new(0),
    });
    let mut children = vec![];

    println!(
        "Fetching {} histories with {} rust threads",
        sh.ids.len(),
        num_threads
    );

    for _ in 1..=num_threads {
        let thread_tx = tx.clone();
        let thread_sh = sh.clone();

        let child = std::thread::spawn(move || do_fetch(thread_tx, thread_sh));
        children.push(child);
    }
    for _ in 1..=sh.ids.len() {
        if let Some(st) = rx.recv().unwrap() {
            print_story(st, sh.ids.len());
        }
    }
    children.into_iter().for_each(|child| child.join().unwrap());
}
