package main

import "testing"

func TestPatchYamlShortID(t *testing.T) {
	cases := map[string]string{
		"    short-id: 0123abcd\n":                    "    short-id: \"0123abcd\"\n",
		"    short-id: 1e5\n":                         "    short-id: \"1e5\"\n",
		"    short-id: 12345678 # note\n":             "    short-id: \"12345678\" # note\n",
		"    short-id:   ABCDEF\n":                    "    short-id:   \"ABCDEF\"\n",
		"reality-opts: {public-key: k, short-id: 01}": "reality-opts: {public-key: k, short-id: \"01\"}",
		"{short-id: 01, public-key: k}":               "{short-id: \"01\", public-key: k}",
		"    short-id: \"0123abcd\"\n":                "    short-id: \"0123abcd\"\n",
		"    short-id: '0123abcd'\n":                  "    short-id: '0123abcd'\n",
		"    short-id: xyz\n":                         "    short-id: xyz\n",
		"    short-id: 0123abcdxyz\n":                 "    short-id: 0123abcdxyz\n",
		"    short-id:\n":                             "    short-id:\n",
		"    short-id: 0123abcd":                      "    short-id: \"0123abcd\"",
	}
	for input, want := range cases {
		if got := string(patchYamlShortID([]byte(input))); got != want {
			t.Errorf("patchYamlShortID(%q) = %q, want %q", input, got, want)
		}
	}
}
