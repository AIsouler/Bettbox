package main

import (
	"encoding/json"
	"reflect"
	"testing"

	"github.com/metacubex/mihomo/log"
)

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

func TestLogHistoryCarriesTime(t *testing.T) {
	handleClearLogs()
	t.Cleanup(func() { handleClearLogs() })
	recordLogHistory(logEntry{
		Event: log.Event{LogLevel: log.WARNING, Payload: "[DNS] timeout"},
		Time:  1760000000123,
	})
	var items []map[string]any
	if err := json.Unmarshal([]byte(handleGetLogs()), &items); err != nil {
		t.Fatal(err)
	}
	if len(items) != 1 {
		t.Fatalf("len = %d, want 1", len(items))
	}
	want := map[string]any{
		"LogLevel": "warning",
		"Payload":  "[DNS] timeout",
		"time":     float64(1760000000123),
	}
	if !reflect.DeepEqual(items[0], want) {
		t.Errorf("entry = %v, want %v", items[0], want)
	}
}
