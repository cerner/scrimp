struct WordStats {
  1: i64 count
  2: double percentage
  3: bool palindrome
}

enum Word {
  BRUMAL = 1
  CYCLOPLEAN = 2
  FANTOD = 3
}

struct Person {
  1: string name
  2: optional Word favoriteWord
}

exception Tantrum {
  1: string complaint
}

service ExampleService {
  map<string, WordStats> textStats(1: string text)

  string greet(1: set<Person> people)

  double random()

  void voidMethod(1: bool throwException) throws (1: Tantrum tantrum)

  oneway void onewayMethod(1: string message)
}