// RUN: %target-swift-frontend -emit-sil -strict-concurrency=complete -disable-availability-checking -verify %s -o /dev/null -swift-version 6 -enable-experimental-feature TransferringArgsAndResults

// REQUIRES: concurrency

// This test makes sure that all of our warnings are errors in swift6 mode.

////////////////////////
// MARK: Declarations //
////////////////////////

class NonSendableType {}

@MainActor func transferToMain<T>(_ t: T) async {}
func useValue<T>(_ t: T) {}
func transferValue<T>(_ t: transferring T) {}

/////////////////
// MARK: Tests //
/////////////////

func testIsolationError() async {
  let x = NonSendableType()
  await transferToMain(x) // expected-error {{transferring 'x' may cause a race}}
  // expected-note @-1 {{'x' is transferred from nonisolated caller to main actor-isolated callee. Later uses in caller could race with potential uses in callee}}
  useValue(x) // expected-note {{access here could race}}
}

func testTransferArgumentError(_ x: NonSendableType) async {
  await transferToMain(x) // expected-error {{transferring 'x' may cause a race}}
  // expected-note @-1 {{transferring task-isolated 'x' to main actor-isolated callee could cause races between main actor-isolated and task-isolated uses}}
}

func testPassArgumentAsTransferringParameter(_ x: NonSendableType) async {
  transferValue(x) // expected-error {{transferring 'x' may cause a race}}
  // expected-note @-1 {{task-isolated 'x' is passed as a transferring parameter; Uses in callee may race with later task-isolated uses}}
}

func testAssignmentIntoTransferringParameter(_ x: transferring NonSendableType) async {
  let y = NonSendableType()
  await transferToMain(x)
  x = y
  useValue(y)
}

func testAssigningParameterIntoTransferringParameter(_ x: transferring NonSendableType, _ y: NonSendableType) async {
  x = y
}

func testIsolationCrossingDueToCapture() async {
  let x = NonSendableType()
  let _ = { @MainActor in
    print(x) // expected-error {{main actor-isolated closure captures value of non-Sendable type 'NonSendableType' from nonisolated context; later accesses to value could race}}
  }
  useValue(x) // expected-note {{access here could race}}
}

func testIsolationCrossingDueToCaptureParameter(_ x: NonSendableType) async {
  let _ = { @MainActor in
    print(x) // expected-error {{task-isolated value of type 'NonSendableType' transferred to main actor-isolated context; later accesses to value could race}}
  }
  useValue(x)
}
