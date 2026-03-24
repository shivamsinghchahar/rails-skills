# React Code Review

Stack-specific review guidance for React applications with TypeScript.

## Stack Detection Patterns

Files indicating React scope:
- `*.tsx`, `*.jsx` in `app/javascript/`, `src/`, `components/`, `pages/`
- `*.test.tsx`, `*.spec.tsx` (test files)
- `package.json` with react/react-dom dependencies

---

## Component Structure

### Single Responsibility

**Check:**
- Components under 200 lines
- Components do one thing
- Complex logic extracted to custom hooks

**Red Flags:**
```tsx
// Bad: Component doing too much
function UserDashboard({ userId }: { userId: string }) {
  const [posts, setPosts] = useState([]);
  const [friends, setFriends] = useState([]);
  const [notifications, setNotifications] = useState([]);
  const [settings, setSettings] = useState({});
  
  useEffect(() => {
    fetchPosts(userId).then(setPosts);
    fetchFriends(userId).then(setFriends);
    fetchNotifications(userId).then(setNotifications);
    fetchSettings(userId).then(setSettings);
  }, [userId]);
  
  // 500 lines of rendering logic...
}

// Good: Split into focused components
function UserDashboard({ userId }: { userId: string }) {
  return (
    <DashboardLayout>
      <UserPosts userId={userId} />
      <UserFriends userId={userId} />
      <UserNotifications userId={userId} />
      <UserSettings userId={userId} />
    </DashboardLayout>
  );
}
```

### Named Exports

**Check:**
- Prefer named exports over default exports
- Enables better refactoring and tree-shaking

**Red Flags:**
```tsx
// Bad: Default export
export default function UserCard() { ... }

// Good: Named export
export function UserCard() { ... }

// Or with re-export
export { UserCard };
```

### Props Interfaces

**Check:**
- Props interface defined (inline or colocated)
- Props destructured in function signature
- No unnecessary prop drilling

**Red Flags:**
```tsx
// Bad: No interface, props drilling
function App() {
  return <Page user={user} theme={theme} />;
}
function Page({ user, theme }: any) {
  return <Layout user={user} theme={theme}><Content user={user} theme={theme} /></Layout>;
}

// Good: Interface, context for shared state
interface AppProps {
  user: User;
  theme: Theme;
}
function App({ user, theme }: AppProps) {
  return (
    <ThemeProvider theme={theme}>
      <UserProvider user={user}>
        <Page />
      </UserProvider>
    </ThemeProvider>
  );
}
```

---

## Hooks

### Rules of Hooks

**Check:**
- Hooks not called conditionally
- Hooks not called in loops
- Hooks always called at top level

**Red Flags:**
```tsx
// Bad: Conditional hook call
function Component({ showCount }: { showCount: boolean }) {
  if (showCount) {
    const count = useCount();  // Violates rules!
  }
  return <div>...</div>;
}

// Bad: Hook in loop
function ComponentList({ items }: { items: Item[] }) {
  items.forEach(item => {
    const data = useData(item.id);  // Violates rules!
  });
}

// Good: Hook in condition (but consider refactor)
function Component({ showCount }: { showCount: boolean }) {
  const countData = useCount();  // Always call
  if (!showCount) return <div>...</div>;
  return <div>Count: {countData.count}</div>;
}
```

### Dependency Arrays

**Check:**
- All reactive values in dependency array
- No lint warnings disabled
- ESLint `react-hooks/exhaustive-deps` passing

**Red Flags:**
```tsx
// Bad: Missing dependencies
useEffect(() => {
  fetchUser(userId);
}, []); // Missing userId!

// Bad: Disabled lint warning
useEffect(() => {
  fetchUser(userId);
  // eslint-disable-next-line react-hooks/exhaustive-deps
}, []);

// Good: All dependencies included
useEffect(() => {
  fetchUser(userId);
}, [userId]);
```

### useEffect Cleanup

**Check:**
- Subscriptions cleaned up
- AbortController for fetch
- Timers cleared

**Red Flags:**
```tsx
// Bad: No cleanup
useEffect(() => {
  const ws = new WebSocket(url);
  channel.subscribe(handler);
  // No unsubscribe!
}, []);

// Bad: setInterval without clear
useEffect(() => {
  const interval = setInterval(() => {
    refetch();
  }, 5000);
  // No clearInterval!
}, []);

// Good: Cleanup function
useEffect(() => {
  const ws = new WebSocket(url);
  ws.onmessage = handler;
  
  return () => {
    ws.close();
    channel.unsubscribe(handler);
  };
}, []);

useEffect(() => {
  const interval = setInterval(refetch, 5000);
  return () => clearInterval(interval);
}, []);
```

### Custom Hooks

**Check:**
- Named with `use` prefix
- Single responsibility
- Returns meaningful values

---

## State Management

### Immutable Updates

**Check:**
- No direct mutation (`.push()`, `.splice()`, `.sort()`)
- Use spread operator or Immer

**Red Flags:**
```tsx
// Bad: Mutation
const [items, setItems] = useState([]);
function addItem(item) {
  items.push(item);      // Mutates!
  setItems(items);       // Won't trigger re-render correctly
}

// Bad: Array index mutation
function updateItem(index) {
  items[index] = newValue;  // Mutates!
  setItems(items);
}

// Good: Immutable
function addItem(item) {
  setItems([...items, item]);
}

function updateItem(index) {
  setItems(items.map((item, i) => i === index ? newValue : item));
}
```

### Colocation

**Check:**
- State placed where used
- Lift state only when needed
- Derived state computed, not stored

**Red Flags:**
```tsx
// Bad: State too high
function App() {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  return <Layout><Sidebar><Dropdown open={isDropdownOpen} onToggle={setIsDropdownOpen} /></Sidebar></Layout>;
}

// Good: State where used
function Sidebar() {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  return <Dropdown open={isDropdownOpen} onToggle={setIsDropdownOpen} />;
}
```

### Server State vs Client State

**Check:**
- Server data in TanStack Query/SWR, not useState
- No useEffect + setState for data fetching

**Red Flags:**
```tsx
// Bad: Copying server state to local
const [users, setUsers] = useState([]);
useEffect(() => {
  fetchUsers().then(data => setUsers(data));
}, []);

// Good: TanStack Query is source of truth
const { data: users } = useQuery({
  queryKey: ['users'],
  queryFn: fetchUsers,
});
```

---

## TypeScript

### Strict Mode

**Check:**
- No `any` without justification
- Proper interface definitions
- Generic types when applicable

**Red Flags:**
```tsx
// Bad: any
function processData(data: any) {
  return data.value;  // No type safety!
}

// Bad: Missing types
function UserCard({ user }) {
  return <div>{user.name}</div>;
}

// Good: Proper types
interface User {
  id: string;
  name: string;
  email: string;
}

function UserCard({ user }: { user: User }) {
  return <div>{user.name}</div>;
}
```

### Event Handlers

**Check:**
- Proper event types
- Not typed as `any`

**Red Flags:**
```tsx
// Bad
function handleClick(event: any) {
  event.preventDefault();
}

// Good
function handleClick(event: React.MouseEvent<HTMLButtonElement>) {
  event.preventDefault();
}
```

### React.FC Usage

**Check:**
- Plain function over React.FC for most cases
- React.FC with generics avoided

**Red Flags:**
```tsx
// Discouraged
const App: React.FC<Props> = ({ children }) => {
  return <div>{children}</div>;
};

// Preferred
function App({ children }: PropsWithChildren) {
  return <div>{children}</div>;
}
```

---

## Performance

### React.memo

**Check:**
- Pure display components memoized
- Not overused (every tiny component)

**Red Flags:**
```tsx
// Bad: Wrapping everything
const SmallComponent = React.memo(function SmallComponent({ value }: { value: string }) {
  return <span>{value}</span>;
});

// Good: Memoize when needed
const UserCard = React.memo(function UserCard({ user }: { user: User }) {
  return <div>{user.name}</div>;
});
```

### List Keys

**Check:**
- Stable, unique keys
- Not using array index for dynamic lists

**Red Flags:**
```tsx
// Bad: Index as key
{items.map((item, i) => <Item key={i} {...item} />)}

// Good: Unique id
{items.map((item) => <Item key={item.id} {...item} />)}
```

### Lazy Loading

**Check:**
- Route-level code splitting with React.lazy
- Suspense for loading states

---

## Accessibility

### Semantic HTML

**Check:**
- `<button>` for clickable elements, not `<div onClick>`
- Proper heading hierarchy
- `<a>` for links, not `<div onClick>`

**Red Flags:**
```tsx
// Bad: Non-semantic clickable
<div onClick={handleClick}>Click me</div>

// Good: Semantic button
<button onClick={handleClick}>Click me</button>
```

### Keyboard Navigation

**Check:**
- Focusable elements
- Tab navigation works
- Enter/Space activation

### Alt Text

**Check:**
- Alt on every img
- Decorative images have alt=""

**Red Flags:**
```tsx
// Bad: Missing alt
<img src={user.avatar} />

// Good: Descriptive alt
<img src={user.avatar} alt={`${user.name}'s profile picture`} />

// Good: Decorative
<img src={decoration} alt="" />
```

---

## React 19 Specific

### useFormStatus

**Check:**
- `useFormStatus` used in a CHILD component, not the same component with `<form>`

**Red Flags:**
```tsx
// Bad: useFormStatus in same component as form
function Form() {
  const { pending } = useFormStatus();  // Always false!
  return <form action={submit}><button disabled={pending}>Send</button></form>;
}

// Good: useFormStatus in child component
function SubmitButton() {
  const { pending } = useFormStatus();
  return <button type="submit" disabled={pending}>Send</button>;
}
function Form() {
  return <form action={submit}><SubmitButton /></form>;
}
```

### use() Hook

**Check:**
- Promises not created in render (causes infinite loop)
- use() with Context works

**Red Flags:**
```tsx
// Bad: Promise created in render
function Component() {
  const data = use(fetch('/api/data'));  // New promise every render = infinite loop!
}

// Good: Promise from props or state
function Component({ dataPromise }: { dataPromise: Promise<Data> }) {
  const data = use(dataPromise);
}
```

---

## Common Anti-Patterns

### Prop Drilling > 2-3 Levels
```tsx
// Bad
<App theme={theme} user={user} settings={settings}>
  <Layout>
    <Sidebar>
      <Nav user={user} settings={settings}>
        <NavItem settings={settings}>

// Good: Use Context
<App>
  <ThemeProvider theme={theme}>
    <UserProvider user={user}>
      <SettingsProvider settings={settings}>
        <Layout><Sidebar><Nav>...</Nav></Sidebar></Layout>
      </SettingsProvider>
    </UserProvider>
  </ThemeProvider>
</App>
```

### Missing Error Boundaries
```tsx
// Good: Error boundary around risky components
<ErrorBoundary>
  <RiskyComponent />
</ErrorBoundary>
```

### Uncontrolled Inputs
```tsx
// Bad: Undefined initial value causes warning
const [value, setValue] = useState(undefined);

// Good: Empty string
const [value, setValue] = useState('');
```

---

## Security Checklist

- [ ] No `dangerouslySetInnerHTML` with user input
- [ ] Input sanitization for XSS prevention
- [ ] No secrets in client-side code
- [ ] Proper authentication token handling
- [ ] HTTPS only for sensitive operations

---

## Testing Checklist

- [ ] Unit tests for custom hooks
- [ ] Component tests for critical UI
- [ ] Integration tests for user flows
- [ ] Test file alongside component (`UserCard.tsx` → `UserCard.test.tsx`)
