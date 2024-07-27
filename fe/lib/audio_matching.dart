import 'dart:math';

int contourMatching(List<int> src, List<int> dst) {
  int INSERTION_COST = 5;
  int SUBSTITUTION_COST(int diff) {
    int m = 1;
    int b = 0;
    int cutoff =
        INSERTION_COST * 1; // limit for cost: implicitly < insertion + deletion
    return min(m * diff + b, cutoff).floor();
  }

  int m = src.length + 1;
  int n = dst.length + 1;
  // dp[i][j] represents the cost from src's tail with length i to dst's tail with length j
  var dp = List<List<int>>.generate(m, (i) => List.generate(n, (j) => 0));
  for (int i = 0; i < m; i++) {
    for (int j = 0; j < n; j++) {
      if (i == 0) {
        // insert all letters of dst if src == ''
        dp[i][j] = INSERTION_COST * j;
      } else if (j == 0) {
        // insert all letters of src if dst == ''
        dp[i][j] = INSERTION_COST * i;
      } else {
        int diff = (src[i - 1] - dst[j - 1]).abs();
        if (diff == 0) {
          // no change if same letter
          dp[i][j] = dp[i - 1][j - 1];
        } else {
          // apply "closest" insertion, deletion, or substitution
          dp[i][j] = [
            SUBSTITUTION_COST(diff) + dp[i - 1][j - 1],
            INSERTION_COST + dp[i - 1][j],
            INSERTION_COST + dp[i][j - 1]
          ].reduce(min);
        }
      }
    }
  }
  // print(dp);
  return dp[m - 1][n - 1];
}

var src = [2, 15, 1, 20, 19]; // BOATS
// var src = [2, 15, 1, 20]; // BOAT
var dst = [6, 12, 15, 1, 20]; // FLOAT

void main() {
  print(contourMatching(src, dst));
}
