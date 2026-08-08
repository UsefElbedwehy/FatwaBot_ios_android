package com.fatwabot.core.common

import java.io.File
import java.nio.file.Files
import java.time.Instant
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/** Mirrors iOS WorshipInboxTests. */
class WorshipInboxTest {
    private lateinit var dir: File
    private lateinit var inbox: WorshipInbox

    @Before
    fun setUp() {
        dir = Files.createTempDirectory("inbox").toFile()
        inbox = WorshipInbox(File(dir, "worship-inbox"))
    }

    @After
    fun tearDown() {
        dir.deleteRecursively()
    }

    private fun entry(
        type: String = "prayer_completed",
        at: Long = Instant.now().epochSecond,
        metadata: Map<String, String> = mapOf("prayer" to "fajr"),
    ) = WorshipInboxEntry(eventType = type, occurredAtEpochSeconds = at, metadata = metadata)

    @Test
    fun `deposit then peek round trips`() {
        val e = entry()
        assertTrue(inbox.deposit(e))
        val peeked = inbox.peek()
        assertEquals(1, peeked.size)
        assertEquals("prayer_completed", peeked[0].eventType)
        assertEquals("fajr", peeked[0].metadata["prayer"])
        assertEquals(e.clientEventId, peeked[0].clientEventId)
    }

    @Test
    fun `peek on an untouched inbox is empty not an error`() {
        // The directory does not exist until the first deposit. Every launch
        // before the user has ever tapped a tile takes this path.
        assertTrue(WorshipInbox(File(dir, "never-used")).peek().isEmpty())
    }

    @Test
    fun `concurrent deposits all survive`() {
        // The reason for one-file-per-entry. Under a shared-list store these
        // interleave into lost updates, and what gets lost is a user's record of
        // an act of worship.
        val pool = Executors.newFixedThreadPool(8)
        repeat(50) { i -> pool.submit { inbox.deposit(entry(metadata = mapOf("i" to "$i"))) } }
        pool.shutdown()
        pool.awaitTermination(10, TimeUnit.SECONDS)

        assertEquals(50, inbox.peek().size)
        assertEquals(50, inbox.peek().mapNotNull { it.metadata["i"] }.toSet().size)
    }

    @Test
    fun `peek is chronological rather than directory order`() {
        val now = Instant.now().epochSecond
        // Deposited newest-first so filesystem order cannot accidentally pass.
        listOf(0L, -300L, -600L).forEach { inbox.deposit(entry(at = now + it)) }
        val times = inbox.peek().map { it.occurredAtEpochSeconds }
        assertEquals(times.sorted(), times)
    }

    @Test
    fun `clear removes only the entries handed back`() {
        val uploaded = entry()
        val arrivedDuringUpload = entry(type = "azkar_completed")
        inbox.deposit(uploaded)
        inbox.deposit(arrivedDuringUpload)

        // The app uploads what it peeked, then clears exactly that. An entry the
        // widget deposited *while* the upload was in flight must survive.
        inbox.clear(listOf(uploaded))

        val remaining = inbox.peek()
        assertEquals(1, remaining.size)
        assertEquals(arrivedDuringUpload.clientEventId, remaining[0].clientEventId)
    }

    @Test
    fun `clearing twice is harmless`() {
        val e = entry()
        inbox.deposit(e)
        inbox.clear(listOf(e))
        inbox.clear(listOf(e))
        assertTrue(inbox.peek().isEmpty())
    }

    @Test
    fun `redepositing the same entry does not duplicate it`() {
        val e = entry()
        inbox.deposit(e)
        inbox.deposit(e)
        // Same client event id, one file. Keeps a retried tap from counting twice.
        assertEquals(1, inbox.peek().size)
    }

    @Test
    fun `a corrupt file does not take the whole inbox down`() {
        val good = entry()
        inbox.deposit(good)
        File(dir, "worship-inbox/broken.json").writeText("not json")
        // One unreadable file must not cost the user every other logged deed.
        val peeked = inbox.peek()
        assertEquals(1, peeked.size)
        assertEquals(good.clientEventId, peeked[0].clientEventId)
    }

    @Test
    fun `deed vocabulary matches what the app records from its own screens`() {
        // A drift here logs deeds that silently never count toward a streak.
        assertEquals("prayer_completed", WorshipDeed.FAJR.eventType)
        assertEquals(mapOf("prayer" to "fajr"), WorshipDeed.FAJR.metadata)
        assertEquals("azkar_completed", WorshipDeed.AZKAR_MORNING.eventType)
        assertEquals(mapOf("category" to "morning"), WorshipDeed.AZKAR_MORNING.metadata)
        assertEquals(WorshipDeed.ASR, WorshipDeed.fromKey("asr"))
        assertNull(WorshipDeed.fromKey("morning_azkar"))
        assertEquals(5, WorshipDeed.prayers.size)
    }

    @Test
    fun `snapshot written before completedToday existed still decodes`() {
        val file = File(dir, "gamification-widget-snapshot.json")
        file.writeText("""{"topStreak":null,"dailyChallenge":null,"generatedAtEpochSeconds":1786230000}""")
        val decoded = GamificationWidgetSnapshotStore(file).read()
        // Must not fail the decode — that would take the streak widget down too.
        assertTrue(decoded != null)
        assertTrue(decoded!!.completedToday.isEmpty())
    }
}
