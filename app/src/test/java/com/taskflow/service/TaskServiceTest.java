package com.taskflow.service;

import com.taskflow.dto.TaskRequest;
import com.taskflow.dto.TaskResponse;
import com.taskflow.entity.Task;
import com.taskflow.entity.TaskStatus;
import com.taskflow.exception.TaskNotFoundException;
import com.taskflow.repository.TaskRepository;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Sort;

import java.util.List;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

@ExtendWith(MockitoExtension.class)
class TaskServiceTest {

    @Mock
    private TaskRepository repository;

    @InjectMocks
    private TaskService service;

    private Task task;

    @BeforeEach
    void setUp() {
        task = new Task("Write tests", "Cover CRUD operations", TaskStatus.TODO);
    }

    @Test
    void createTrimsTitleAndDefaultsStatusToTodo() {
        when(repository.save(any(Task.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TaskResponse response = service.create(
                new TaskRequest("  Write tests  ", "Description", null));

        assertEquals("Write tests", response.title());
        assertEquals("Description", response.description());
        assertEquals(TaskStatus.TODO, response.status());
        verify(repository).save(any(Task.class));
    }

    @Test
    void createUsesProvidedStatus() {
        when(repository.save(any(Task.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TaskResponse response = service.create(
                new TaskRequest("In progress", null, TaskStatus.IN_PROGRESS));

        assertEquals(TaskStatus.IN_PROGRESS, response.status());
    }

    @Test
    void listReturnsMappedResponses() {
        when(repository.findAll(any(Sort.class))).thenReturn(List.of(task));

        List<TaskResponse> result = service.list();

        assertEquals(1, result.size());
        assertEquals("Write tests", result.get(0).title());
        assertEquals(TaskStatus.TODO, result.get(0).status());
        verify(repository).findAll(any(Sort.class));
    }

    @Test
    void listReturnsEmptyListWhenNoTasksExist() {
        when(repository.findAll(any(Sort.class))).thenReturn(List.of());

        assertTrue(service.list().isEmpty());
    }

    @Test
    void getReturnsTaskWhenFound() {
        when(repository.findById(1L)).thenReturn(Optional.of(task));

        TaskResponse response = service.get(1L);

        assertEquals("Write tests", response.title());
        assertEquals("Cover CRUD operations", response.description());
    }

    @Test
    void getThrowsWhenTaskDoesNotExist() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(TaskNotFoundException.class, () -> service.get(99L));
    }

    @Test
    void updateChangesFieldsAndKeepsExistingStatusWhenStatusIsNull() {
        when(repository.findById(1L)).thenReturn(Optional.of(task));
        when(repository.save(any(Task.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TaskResponse response = service.update(
                1L, new TaskRequest("  Updated title ", "Updated description", null));

        assertEquals("Updated title", response.title());
        assertEquals("Updated description", response.description());
        assertEquals(TaskStatus.TODO, response.status());
        verify(repository).save(task);
    }

    @Test
    void updateUsesProvidedStatus() {
        when(repository.findById(1L)).thenReturn(Optional.of(task));
        when(repository.save(any(Task.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        TaskResponse response = service.update(
                1L, new TaskRequest("Updated", null, TaskStatus.DONE));

        assertEquals(TaskStatus.DONE, response.status());
    }

    @Test
    void updateThrowsWhenTaskDoesNotExist() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(TaskNotFoundException.class,
                () -> service.update(
                        99L, new TaskRequest("Updated", null, TaskStatus.DONE)));

        verify(repository, never()).save(any(Task.class));
    }

    @Test
    void deleteRemovesExistingTask() {
        when(repository.findById(1L)).thenReturn(Optional.of(task));

        service.delete(1L);

        verify(repository).delete(task);
    }

    @Test
    void deleteThrowsWhenTaskDoesNotExist() {
        when(repository.findById(99L)).thenReturn(Optional.empty());

        assertThrows(TaskNotFoundException.class, () -> service.delete(99L));
        verify(repository, never()).delete(any(Task.class));
    }
}
