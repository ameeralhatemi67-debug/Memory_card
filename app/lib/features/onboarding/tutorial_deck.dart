import '../../data/store.dart';

/// "How it works", in the "Start here" folder: a short real deck that teaches the app while you use it.
const tutorialDeckName = 'How it works';

const tutorialCards = <CardDraft>[
  CardDraft(
    front: 'You remembered the answer. Which way do you swipe?',
    back: 'Right: the card goes to the back of the stack',
    label: 'swiping',
  ),
  CardDraft(
    front: "You didn't know it. Which way do you swipe?",
    back: 'Left: it comes back in 8–20 cards',
    label: 'swiping',
    hook: 'Not inside working memory, so the next try is a real recall',
  ),
  CardDraft(
    front: 'You swiped the wrong way by accident. What now?',
    back: 'Tap Undo on the chip under the card',
    label: 'undo',
  ),
  CardDraft(
    front: 'How does Memory Card know a card was easy?',
    back: 'It reads your speed and hesitation',
    label: 'smart grading',
    hook: 'Tap the grade on the chip to change it any time',
  ),
  CardDraft(
    front: 'What does the fan on a deck bar show?',
    back: 'How many of its cards are strong: each step is 20 %',
    label: 'progress',
  ),
  CardDraft(
    front: 'What does "slipping" mean?',
    back: 'Predicted recall dropped below 90 %',
    label: 'memory',
    hook: 'The Daily mix gathers slipping cards from every deck',
  ),
  CardDraft(
    front: 'Where are your folders?',
    back: 'Tap the logo at the top left',
    label: 'library',
  ),
  CardDraft(
    front: 'How do you add your own cards?',
    back: 'The + diamond at the bottom',
    label: 'creating',
    hook: 'Paste a whole list at once with Import CSV',
  ),
  CardDraft(
    front: 'What protects your streak on a busy day?',
    back: 'A grace shield: two every month',
    label: 'streak',
  ),
  CardDraft(
    front: 'You reached the daily goal. Is the session over?',
    back: 'Only if you want: the stack keeps going',
    label: 'goal',
  ),
];
