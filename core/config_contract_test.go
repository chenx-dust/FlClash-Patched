package main

import (
	"encoding/json"
	"os"
	"reflect"
	"strings"
	"testing"

	LC "github.com/metacubex/mihomo/listener/config"
)

func configPatchFixture(t *testing.T) []byte {
	t.Helper()
	data, err := os.ReadFile("../test/fixtures/config_patch.json")
	if err != nil {
		t.Fatal(err)
	}
	return data
}

func jsonContractFields(t *testing.T, typ reflect.Type) map[string]int {
	t.Helper()
	fields := make(map[string]int)
	for i := 0; i < typ.NumField(); i++ {
		field := typ.Field(i)
		name := strings.Split(field.Tag.Get("json"), ",")[0]
		if name == "" || name == "-" {
			t.Fatalf("%s.%s needs an explicit JSON contract", typ, field.Name)
		}
		if _, exists := fields[name]; exists {
			t.Fatalf("%s has duplicate JSON field %q", typ, name)
		}
		fields[name] = i
	}
	return fields
}

func checkConfigContract(t *testing.T, data []byte, typ reflect.Type) {
	t.Helper()
	var values map[string]json.RawMessage
	if err := json.Unmarshal(data, &values); err != nil {
		t.Fatal(err)
	}
	fields := jsonContractFields(t, typ)
	for name, index := range fields {
		value, exists := values[name]
		if !exists {
			t.Errorf("%s.%s is missing from the shared Dart/Go fixture", typ, name)
			continue
		}
		fieldType := typ.Field(index).Type
		if fieldType.Kind() == reflect.Pointer {
			fieldType = fieldType.Elem()
		}
		if fieldType.Kind() == reflect.Struct {
			checkConfigContract(t, value, fieldType)
		}
	}
	for name := range values {
		if _, exists := fields[name]; !exists {
			t.Errorf("%s does not accept fixture field %q", typ, name)
		}
	}
}

func TestUpdateParamsJSONContract(t *testing.T) {
	data := configPatchFixture(t)
	checkConfigContract(t, data, reflect.TypeFor[UpdateParams]())
	var params UpdateParams
	if err := json.Unmarshal(data, &params); err != nil {
		t.Fatal(err)
	}
}

func TestPatchTunAppliesEveryContractField(t *testing.T) {
	var params UpdateParams
	if err := json.Unmarshal(configPatchFixture(t), &params); err != nil {
		t.Fatal(err)
	}
	if params.Tun == nil {
		t.Fatal("fixture must include TUN settings")
	}
	sample := reflect.ValueOf(params.Tun).Elem()
	targetFields := jsonContractFields(t, reflect.TypeFor[LC.Tun]())
	for name, index := range jsonContractFields(t, sample.Type()) {
		t.Run(name, func(t *testing.T) {
			targetIndex, exists := targetFields[name]
			if !exists {
				t.Fatalf("TUN target has no field for %q", name)
			}
			value := sample.Field(index)
			optional := value.Kind() == reflect.Pointer
			if optional {
				if value.IsNil() {
					t.Fatal("fixture must provide a non-null value")
				}
				value = value.Elem()
			}
			if value.IsZero() {
				t.Fatal("fixture must provide a nonzero value to detect missing assignments")
			}
			var patch tunSchema
			patchField := reflect.ValueOf(&patch).Elem().Field(index)
			patchField.Set(sample.Field(index))
			var target LC.Tun
			targetField := reflect.ValueOf(&target).Elem().Field(targetIndex)
			patchTun(&target, &patch)
			if !reflect.DeepEqual(targetField.Interface(), value.Interface()) {
				t.Fatalf("patchTun did not apply %q: got %v, want %v", name, targetField.Interface(), value.Interface())
			}
			if optional {
				patchTun(&target, &tunSchema{})
				if !reflect.DeepEqual(targetField.Interface(), value.Interface()) {
					t.Fatalf("omitting %q changed its existing value", name)
				}
			}
			zero := reflect.Zero(value.Type())
			if value.Kind() == reflect.Slice {
				zero = reflect.MakeSlice(value.Type(), 0, 0)
			}
			if optional {
				patchField.Set(reflect.New(value.Type()))
				patchField.Elem().Set(zero)
			} else {
				patchField.Set(zero)
			}
			patchTun(&target, &patch)
			if !reflect.DeepEqual(targetField.Interface(), zero.Interface()) {
				t.Fatalf("patchTun did not clear %q: got %v", name, targetField.Interface())
			}
		})
	}
}
