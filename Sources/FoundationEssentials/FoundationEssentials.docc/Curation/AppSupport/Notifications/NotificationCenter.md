# ``/FoundationEssentials/NotificationCenter``


## Topics

### Getting the default notification center

- ``default``

### Creating a custom notification center

- ``init()``

### Declaring a notification message

- ``MainActorMessage``
- ``AsyncMessage``

### Using notification message identifiers

- ``MessageIdentifier``
- ``BaseMessageIdentifier``

### Observing notification messages

- ``addObserver(of:for:using:)-5sv0y``      <!-- func addObserver<Identifier, Message>(of subject: Message.Subject, for identifier: Identifier, using observer: @escaping @MainActor (Message) -> Void) -> NotificationCenter.ObservationToken where Identifier : NotificationCenter.MessageIdentifier, Message : NotificationCenter.MainActorMessage, Message == Identifier.MessageType, Message.Subject : AnyObject -->
- ``addObserver(of:for:using:)-273rk`` <!-- func addObserver<Identifier, Message>(of subject: Message.Subject.Type, for identifier: Identifier, using observer: @escaping @MainActor (Message) -> Void) -> NotificationCenter.ObservationToken where Identifier : NotificationCenter.MessageIdentifier, Message : NotificationCenter.MainActorMessage, Message == Identifier.MessageType -->
- ``addObserver(of:for:using:)-4deos``         <!-- func addObserver<Message>(of subject: Message.Subject? = nil, for messageType: Message.Type, using observer: @escaping @MainActor (Message) -> Void) -> NotificationCenter.ObservationToken where Message : NotificationCenter.MainActorMessage, Message.Subject : AnyObject -->
- ``addObserver(of:for:using:)-(Message.Subject,_,(Message)->Void)``               <!-- func addObserver<Identifier, Message>(of subject: Message.Subject, for identifier: Identifier, using observer: @escaping @Sendable (Message) async -> Void) -> NotificationCenter.ObservationToken where Identifier : NotificationCenter.MessageIdentifier, Message : NotificationCenter.AsyncMessage, Message == Identifier.MessageType, Message.Subject : AnyObject -->
- ``addObserver(of:for:using:)-(_,Message.Type,(Message)->Void)``                  <!-- func addObserver<Message>(of subject: Message.Subject? = nil, for messageType: Message.Type, using observer: @escaping @Sendable (Message) async -> Void) -> NotificationCenter.ObservationToken where Message : NotificationCenter.AsyncMessage, Message.Subject : AnyObject -->
- ``addObserver(of:for:using:)-(Message.Subject.Type,_,(Message)->Void)``          <!-- func addObserver<Identifier, Message>(of subject: Message.Subject.Type, for identifier: Identifier, using observer: @escaping @Sendable (Message) async -> Void) -> NotificationCenter.ObservationToken where Identifier : NotificationCenter.MessageIdentifier, Message : NotificationCenter.AsyncMessage, Message == Identifier.MessageType -->
- ``removeObserver(_:)``
- ``ObservationToken``

### Receiving notification messages as asynchronous sequences
- ``messages(of:for:bufferSize:)-(Message.Subject,_,_)``                           <!-- func messages<Identifier, Message>(of subject: Message.Subject, for identifier: Identifier, bufferSize limit: Int = 10) -> some Sendable & AsyncSequence<Message, Never> where Identifier : NotificationCenter.MessageIdentifier, Message : NotificationCenter.AsyncMessage, Message == Identifier.MessageType, Message.Subject : AnyObject -->
- ``messages(of:for:bufferSize:)-(_,Message.Type,_)``                              <!-- func messages<Message>(of subject: Message.Subject? = nil, for messageType: Message.Type, bufferSize limit: Int = 10) -> some Sendable & AsyncSequence<Message, Never> where Message : NotificationCenter.AsyncMessage, Message.Subject : AnyObject -->
- ``messages(of:for:bufferSize:)-(Message.Subject.Type,_,_)``                      <!-- func messages<Identifier, Message>(of subject: Message.Subject.Type, for identifier: Identifier, bufferSize limit: Int = 10) -> some Sendable & AsyncSequence<Message, Never> where Identifier : NotificationCenter.MessageIdentifier, Message : NotificationCenter.AsyncMessage, Message == Identifier.MessageType -->

### Posting notification messages

- ``post(_:subject:)-6cbv2``                                                       <!-- @MainActor func post<Message>(_ message: Message, subject: Message.Subject) where Message : NotificationCenter.MainActorMessage, Message.Subject : AnyObject -->
- ``post(_:)-2vx4i``                                                               <!-- @MainActor func post<Message>(_ message: Message) where Message : NotificationCenter.MainActorMessage -->
- ``post(_:subject:)-uso3``                                                        <!-- func post<Message>(_ message: Message, subject: Message.Subject) where Message : NotificationCenter.AsyncMessage, Message.Subject : AnyObject -->
- ``post(_:)-5s5rj``                                                               <!-- func post<Message>(_ message: Message) where Message : NotificationCenter.AsyncMessage -->

